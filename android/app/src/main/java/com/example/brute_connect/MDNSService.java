package com.example.brute_connect;

import android.content.Context;
import android.net.nsd.NsdManager;
import android.net.nsd.NsdServiceInfo;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.os.ext.SdkExtensions;
import android.util.Log;

import java.io.IOException;
import java.net.InetAddress;
import java.net.ServerSocket;
import java.util.List;
import java.util.Map;

public class MDNSService {
    private static final String TAG = "MDNSService";
    private static final String SERVICE_NAME = "Brute Connect";
    private static final String SERVICE_TYPE = "_mdnsconnect._udp";
//    private static final int SERVICE_PORT = 55555;

    private NsdManager nsdManager;
    private NsdManager.RegistrationListener registrationListener;
    private NsdManager.DiscoveryListener discoveryListener;
    private DeviceDiscoveryListener deviceDiscoveryListener;
    private NsdManager.ResolveListener resolveListener;

    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    private String serviceName;
    private boolean isRegistered = false;
    private boolean isDiscovering = false;

    private final Context context;
    private ServerSocket serverSocket;
    private int localPort;

    public interface DeviceDiscoveryListener {
        void onDeviceDiscovered(List<Map<String, Object>> devices);
    }

    public MDNSService(Context context, DeviceDiscoveryListener listener) {
        this.context = context;
        this.deviceDiscoveryListener = listener;
        this.nsdManager = (NsdManager) context.getSystemService(Context.NSD_SERVICE);

        // Find the free port and store it for mDNS service.
        this.initializeServerSocket();
    }

    /**
     * Helps to get the next free port to run the mDNS service.
     */
    private void initializeServerSocket() {

        try {
            // Ask the system for a free port
            serverSocket = new ServerSocket(0);
            localPort = serverSocket.getLocalPort(); // OS-chosen port
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    /**
     * Creates the mDNS service, and registers it on the local network.
     */
    protected void startBroadcast() {
        if (isRegistered) {
            Log.d(TAG, "Broadcasting already started");
            return;
        }

        // Create the NsdServiceInfo object, and populate it.
        NsdServiceInfo serviceInfo = new NsdServiceInfo();

        // The name is subject to change based on conflicts
        // with other services advertised on the same network.
        serviceInfo.setServiceName(SERVICE_NAME);
        serviceInfo.setServiceType(SERVICE_TYPE);
        serviceInfo.setPort(localPort);

        // create a registration listener.
        registrationListener = new NsdManager.RegistrationListener() {
            @Override
            public void onServiceRegistered(NsdServiceInfo serviceInfo) {
                // Save the service name because Android may have changed it
                serviceName = serviceInfo.getServiceName();
                isRegistered = true;
                Log.d(TAG, "Service registered: " + serviceName);
            }

            @Override
            public void onRegistrationFailed(NsdServiceInfo serviceInfo, int errorCode) {
                isRegistered = false;
                Log.e(TAG, "Registration failed: " + errorCode);
            }

            @Override
            public void onServiceUnregistered(NsdServiceInfo serviceInfo) {
                isRegistered = false;
                Log.d(TAG, "Service unregistered: " + serviceName);
            }

            @Override
            public void onUnregistrationFailed(NsdServiceInfo serviceInfo, int errorCode) {
                Log.e(TAG, "Unregistration failed: " + errorCode);
            }
        };

        // Register service on the local network with the registrationListener instance of NsdManager.RegistrationListener.
        nsdManager.registerService(
                serviceInfo, NsdManager.PROTOCOL_DNS_SD, registrationListener);
    }

    /**
     * Creates an discoveryListener and finds services in the network.
     */
    protected void startDiscovery() {
        if (isDiscovering) {
            Log.d(TAG, "Discovery already in progress.");
            return;
        }

        // Instantiate a new DiscoveryListener.
        discoveryListener = new NsdManager.DiscoveryListener() {
            @Override
            public void onDiscoveryStarted(String serviceType) {
                isDiscovering = true;
                Log.d(TAG, "Service discovery started");
            }

            @Override
            public void onDiscoveryStopped(String serviceType) {
                isDiscovering = false;
                Log.i(TAG, "Discovery stopped: " + serviceType);
            }

            @Override
            public void onServiceFound(NsdServiceInfo serviceInfo) {
                // TODO: 2-tasks
                // 1. Create a logic to find the service by SERVICE_TYPE.
                // 2. store the device info by the serviceInfo.
                resolveService(serviceInfo);

            }

            @Override
            public void onServiceLost(NsdServiceInfo serviceInfo) {

            }

            @Override
            public void onStartDiscoveryFailed(String serviceType, int errorCode) {
                isDiscovering = false;
                nsdManager.stopServiceDiscovery(this);
                Log.e(TAG, "Discovery failed: Error code:" + errorCode);
            }

            @Override
            public void onStopDiscoveryFailed(String serviceType, int errorCode) {
                nsdManager.stopServiceDiscovery(this);
                Log.e(TAG, "Discovery failed: Error code:" + errorCode);
            }
        };

        // discover services on local network with the discoveryListener instance of NsdManger.DiscoveryListener.
        nsdManager.discoverServices(
                SERVICE_TYPE, NsdManager.PROTOCOL_DNS_SD, discoveryListener);

    }

    private void resolveService(NsdServiceInfo serviceInfo) {
        resolveListener = new NsdManager.ResolveListener() {
            @Override
            public void onResolveFailed(NsdServiceInfo serviceInfo, int errorCode) {
                // Called when the resolve fails. Use the error code to debug.
                Log.e(TAG, "Resolve failed: " + errorCode);
            }

            @Override
            public void onServiceResolved(NsdServiceInfo serviceInfo) {
                Log.e(TAG, "Resolve Succeeded. " + serviceInfo);

                if (serviceInfo.getServiceName().equals(serviceName)) {
                    Log.d(TAG, "Same IP.");
                    return;
                }
                int port = serviceInfo.getPort();
                InetAddress host = serviceInfo.getHost();
            }
        };
    }

    public void stopBroadcast() {
        if (isRegistered && nsdManager != null && registrationListener != null) {
            try {
                nsdManager.unregisterService(registrationListener);
                isRegistered = false;
                Log.d(TAG, "Service unregistered");
            } catch (Error e) {
                Log.e(TAG, "Error unregistering service.", e);
            }
            registrationListener = null;
        }
    }

    public void stopDiscovery() {
        if (isDiscovering && nsdManager != null && discoveryListener != null) {
            try {
                nsdManager.stopServiceDiscovery(discoveryListener);

                // if statement is from auto-complete by the quick fix.
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && SdkExtensions.getExtensionVersion(Build.VERSION_CODES.TIRAMISU) >= 7) {
                    nsdManager.stopServiceResolution(resolveListener);
                    Log.d(TAG, "Stopped resolving.");
                }
                isDiscovering = false;
                Log.d(TAG, "Stopped discovery.");
            } catch (Error e) {
                Log.e(TAG, "Error stopping discovery", e);
            }
            discoveryListener = null;
            resolveListener = null;
        }
    }

    public void stopService() {
        stopDiscovery();
        stopBroadcast();
    }

}
