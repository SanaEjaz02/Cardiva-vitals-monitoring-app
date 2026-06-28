package com.cardiva.cardiva

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import org.conscrypt.Conscrypt
import java.security.Security

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Install Conscrypt as the first TLS provider — bypasses the broken
        // ProviderInstaller on Infinix XOS, which blocks Firestore's gRPC.
        Security.insertProviderAt(Conscrypt.newProvider(), 1)
        super.onCreate(savedInstanceState)
    }
}
