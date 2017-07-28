package red.tel.chat;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.support.v4.content.LocalBroadcastManager;

public class EventBus {

    public enum Event {
        CONNECTED,
        DISCONNECTED,
        AUTHENTICATED,
        CONTACTS,
        PRESENCE,
        TEXT
    }

    public interface Listener {
        void onEvent();
    }

    public static void announce(Event event) {
        Intent intent = new Intent(event.toString());
        Context context = ChatApp.getContext().getApplicationContext();
        LocalBroadcastManager.getInstance(context).sendBroadcast(intent);
    }

    public static BroadcastReceiver listenFor(Context context, Event event, Listener listener) {
        IntentFilter intentFilter = new IntentFilter(event.toString());

        BroadcastReceiver broadcastReceiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                listener.onEvent();
            }
        };

        LocalBroadcastManager.getInstance(context).registerReceiver(broadcastReceiver, intentFilter);
        return broadcastReceiver;
    }
}
