package com.example.brute_connect;

import android.content.Context;
import android.net.nsd.NsdManager;
import android.os.Handler;
import android.os.Looper;

import java.util.List;
import java.util.Map;

public class MDNSService {
    private static final String TAG = "MDNSService";
    private static final String SERVICE_TYPE = "_mdnsconnect._tcp";
    private static final int SERVICE_PORT = 55555;

    private NsdManager nsdManager;
    private NsdManager.RegistrationListener registrationListener;
    private NsdManager.DiscoveryListener discoveryListener;
    private DeviceDiscoveryListener deviceDiscoveryListener;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    private final Context context;

    public interface DeviceDiscoveryListener {
        void onDeviceDiscovered(List<Map<String, Object>> devices);
    }

    public MDNSService(Context context, DeviceDiscoveryListener listener) {
        this.context = context;
        this.deviceDiscoveryListener = listener;
        this.nsdManager = (NsdManager) context.getSystemService(Context.NSD_SERVICE);
    }
}
