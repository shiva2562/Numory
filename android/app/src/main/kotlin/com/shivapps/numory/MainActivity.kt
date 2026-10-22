package com.shivapps.numory

import android.os.Bundle
import com.google.android.gms.games.PlayGamesSdk
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Play Games needs its project ID (res/values/games.xml) before any
        // sign-in or leaderboard call; without one it would crash, so skip it.
        if (getString(R.string.game_services_project_id).isNotBlank()) {
            PlayGamesSdk.initialize(this)
        }
    }
}
