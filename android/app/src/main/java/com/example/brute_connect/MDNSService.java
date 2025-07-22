package com.example.brute_connect;

import android.content.Context;
import android.net.nsd.NsdManager;
import android.net.nsd.NsdServiceInfo;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import java.io.IOException;
import java.net.ServerSocket;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

public class MDNSService {
    private static final String TAG = "MDNSService";
    private static final String SERVICE_NAME = "bruteconnect";
    private static final String SERVICE_TYPE = "_mdnsconnect._udp";
    private static  ServerSocket serverSocket;
//    private static final int SERVICE_PORT = 55555;

    private final NsdManager nsdManager;
    private NsdManager.RegistrationListener registrationListener;
    private NsdManager.DiscoveryListener discoveryListener;
    private MDNSServiceListener mdnsServiceListener;
    private NsdManager.ResolveListener resolveListener;

    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    private String serviceName;
    private String ownIP;
    private boolean isRegistered = false;
    private boolean isDiscovering = false;

    private final Map<String, Map<String, Object>> discoveredDevicesByIp = new HashMap<>();
    private final Set<String> resolveInProgress = new HashSet<>();

    private int localPort;

    public interface MDNSServiceListener {
        void onDeviceDiscovered(List<Map<String, Object>> devices);
        void onServiceRegistered();
    }


    public MDNSService(Context context, MDNSServiceListener listener) {
        this.mdnsServiceListener = listener;
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
    protected void startBroadcast(int socketPort) {
        if (isRegistered) {
            Log.d(TAG, "Broadcasting already started");
            notifyServiceRegistered();
            return;
        }

        // Create the NsdServiceInfo object, and populate it.
        NsdServiceInfo serviceInfo = new NsdServiceInfo();

        // The name is subject to change based on conflicts
        // with other services advertised on the same network.
        serviceInfo.setServiceName(SERVICE_NAME);
        serviceInfo.setServiceType(SERVICE_TYPE);
        serviceInfo.setPort(localPort);
        serviceInfo.setAttribute("socketPort", String.valueOf(socketPort));

        // create a registration listener.
        registrationListener = new NsdManager.RegistrationListener() {
            @Override
            public void onServiceRegistered(NsdServiceInfo serviceInfo) {
                // Save the service name because Android may have changed it
                serviceName = serviceInfo.getServiceName();
                isRegistered = true;
                Log.d(TAG, "Service registered: " + serviceName);
                Log.d(TAG, "Service registered: " + SERVICE_TYPE);
                Log.d(TAG, "Service registered: " + localPort);

                if (!serverSocket.isClosed()) {
                    try {
                        serverSocket.close();
                    } catch (IOException e) {
                        throw new RuntimeException(e);
                    }
                }

                // Invoke callback that notifies dart file, that service is registered,
                // So, start the discovery.
                notifyServiceRegistered();

//                // ✅ Start discovery after successful registration
//                if (!isDiscovering) {
//                    startDiscovery();
//                }
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
        Log.d(TAG, "Attempting to register service: " + serviceName);
    }

    /**
     * Creates an discoveryListener and finds services in the network.
     */
    protected void startDiscovery() {
        if (isDiscovering) {
            Log.d(TAG, "Discovery already in progress.");
            return;
        }

        // Clear previous discoveries
        synchronized (discoveredDevicesByIp) {
            discoveredDevicesByIp.clear();
        }
        synchronized (resolveInProgress) {
            resolveInProgress.clear();
        }
        notifyDevicesUpdated();

        // Instantiate a new DiscoveryListener.
        discoveryListener = new NsdManager.DiscoveryListener() {
            @Override
            public void onDiscoveryStarted(String serviceType) {
                isDiscovering = true;
                Log.d(TAG, "Service discovery started:" + serviceType);
            }

            @Override
            public void onServiceFound(NsdServiceInfo serviceInfo) {
                // TODO: 2-tasks
                // 1. Create a logic to uniquely identify services from each device.
                // Work on SERVICE_NAME,
                // like, unique-id generated for each device, or using device name
                // 2. On service found, if its new service, call resolveService().
                // Maybe, use a DS, that stores all the devices found.
                // NOTE: so find a way to store data for each device, such that there uniquely identified.
                Log.d(TAG, "Found service: " + serviceInfo.getServiceName());

                String foundService = serviceInfo.getServiceName();
                if (isRegistered && foundService.equals(serviceName)) {
//                    ownIP = serviceInfo.getHost().getHostAddress();
                    Log.d(TAG, "Found our own service, ignoring: " + foundService);
                    Log.d(TAG, String.valueOf(localPort));
                    return;
                }

                Log.d(TAG, "Found service: " + foundService);

                // Avoid resolving the same service multiple times simultaneously
                synchronized (resolveInProgress) {
                    if (resolveInProgress.contains(foundService)) {
                        Log.d(TAG, "Already resolving service: " + foundService);
                        return;
                    }

                    resolveInProgress.add(foundService);
                }

                resolveService(serviceInfo);
            }

            @Override
            public void onServiceLost(NsdServiceInfo serviceInfo) {
                String lostService = serviceInfo.getServiceName();
                Log.d(TAG, "Service lost: " + lostService);

                synchronized (resolveInProgress) {
                    resolveInProgress.remove(lostService);
                }
            }

            @Override
            public void onDiscoveryStopped(String serviceType) {
                isDiscovering = false;
                Log.i(TAG, "Discovery stopped: " + serviceType);
            }

            @Override
            public void onStartDiscoveryFailed(String serviceType, int errorCode) {
                isDiscovering = false;
//                nsdManager.stopServiceDiscovery(discoveryListener);
                Log.e(TAG, "Discovery failed: Error code:" + errorCode);
            }

            @Override
            public void onStopDiscoveryFailed(String serviceType, int errorCode) {
//                nsdManager.stopServiceDiscovery(discoveryListener);
                Log.e(TAG, "Discovery failed: Error code:" + errorCode);
            }
        };

        // discover services on local network with the discoveryListener instance of NsdManger.DiscoveryListener.
        nsdManager.discoverServices(
                SERVICE_TYPE, NsdManager.PROTOCOL_DNS_SD, discoveryListener);
        Log.d("MDNSService", "Starting discovery with listener: " + discoveryListener.toString());

    }

    private void resolveService(NsdServiceInfo serviceInfo) {
        // TODO:
        // 1. Get things you need to store from the device discovery by mDNS.
        // 2. After that, what DS to use.
        // 3. How to condition on finding a mDNS service,
        //  NOTE: like, how do we know that the service is already found and no need to resolve it.
//        final String serviceToResolve = serviceInfo.getServiceName();

        resolveListener = new NsdManager.ResolveListener() {
            @Override
            public void onResolveFailed(NsdServiceInfo serviceInfo, int errorCode) {
                final String resolvedName = serviceInfo.getServiceName();
                // Called when the resolve fails. Use the error code to debug.
                Log.e(TAG, "Resolve failed for " + resolvedName + ": " + errorCode);

                synchronized (resolveInProgress) {
                    resolveInProgress.remove(resolvedName);
                }
            }

            @Override
            public void onServiceResolved(NsdServiceInfo resolveService) {
                String resolvedServiceName = resolveService.getServiceName();
                String resolvedHostAddress = resolveService.getHost().getHostAddress();
                int resolvedPort = resolveService.getPort();

                Log.d(TAG, "Resolved service: " + resolvedServiceName +
                        " at " + resolvedHostAddress + ":" + resolvedPort);

                synchronized (resolveInProgress) {
                    resolveInProgress.remove(resolvedServiceName);
                }

                Log.d(TAG, resolveService.getAttributes().toString());

                // Save our own IP address if this is our service
                if (serviceName != null && resolvedServiceName.equals(serviceName)) {
                    ownIP = resolvedHostAddress;
                    Log.d(TAG, "Identified own device IP: /////////////" + ownIP);
                    return;
                }

                // Skip our own service by checking IP
                if (ownIP != null && resolvedHostAddress.equals(ownIP)) {
                    Log.d(TAG, "Skipping our own service based on IP: " + resolvedHostAddress);
                    return;
                }


                // Get device detailed and store it.
                // Read device attributes
                Map<String, String> attributeMap = new HashMap<>();
                Map<String, byte[]> attributes = resolveService.getAttributes();
                if (attributes != null) {
                    for (String key : attributes.keySet()) {
                        byte[] value = attributes.get(key);
                        if (value != null) {
                            attributeMap.put(key, new String(value, StandardCharsets.UTF_8));
                        }
                    }
                }
                Log.d(TAG, "Attributes: " + attributeMap.toString());

                // Try to get a device ID from attributes
                String deviceName = attributeMap.get("deviceName");
                if (deviceName == null) {
                    deviceName = resolvedServiceName;
                }

                int socketPort = Integer.parseInt(attributeMap.get("socketPort"));

                // Create or update device info map
                Map<String, Object> deviceInfo = new HashMap<>();
                deviceInfo.put("deviceName", deviceName);
                deviceInfo.put("deviceIp", resolvedHostAddress);
                deviceInfo.put("devicePort", resolvedPort);
                deviceInfo.put("deviceSocketPort", socketPort);

//                deviceInfo.putAll(attributeMap);

                // Use IP as key if no device ID available
//                String deviceKey = deviceId != null ? deviceId : hostAddress;
                String deviceKey = resolvedHostAddress;
                discoveredDevicesByIp.put(deviceKey, deviceInfo);
                Log.d(TAG, deviceInfo.toString());
                notifyDevicesUpdated();


//                InetAddress host;
                // Old (deprecated)
                // InetAddress host = serviceInfo.getHost();

                // New (recommended)
//                List<InetAddress> addresses = null;
//                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R
//                        && android.os.ext.SdkExtensions.getExtensionVersion(android.os.Build.VERSION_CODES.TIRAMISU) >= 7) {
//                    addresses = serviceInfo.getHostAddresses();
//                    hostAddress = addresses.isEmpty() ? null : addresses.get(0);
//                } else {
//                    // Deprecated fallback for older OS versions
//                    hostAddress = serviceInfo.getHost();
//                }
            }
        };

        try {
            nsdManager.resolveService(serviceInfo, resolveListener);
        } catch (Exception e) {
            Log.e(TAG, "Error resolving service: " + e.getMessage());
            synchronized (resolveInProgress) {
                resolveInProgress.remove(serviceInfo.getServiceName());
            }
        }
    }

    private void notifyDevicesUpdated() {
        if (mdnsServiceListener != null) {
            List<Map<String, Object>> devicesList;
            synchronized (discoveredDevicesByIp) {
                devicesList = new ArrayList<>(discoveredDevicesByIp.values());
            }

            mainHandler.post(() -> {
                mdnsServiceListener.onDeviceDiscovered(devicesList);
            });
        }
    }

    private void notifyServiceRegistered() {
        mainHandler.post(() -> {
            mdnsServiceListener.onServiceRegistered();
        });
    }

    public void stopDiscovery() {
        if (isDiscovering && nsdManager != null && discoveryListener != null) {
            try {
                Log.d("MDNSService", "Starting discovery with listener: " + discoveryListener.toString());
                nsdManager.stopServiceDiscovery(discoveryListener);

            } catch (IllegalArgumentException e) {
                // Log the error, but it might be okay if it's already stopped
                Log.e("MDNSService", "Error stopping discovery: " + e.getMessage());

            } finally {
                isDiscovering = false;
                discoveryListener = null;
//                resolveInProgress.clear();
            }
        }
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

    public void stopService() {
        stopDiscovery();
        stopBroadcast();
    }

}
