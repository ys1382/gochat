package red.tel.chat;

import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.preference.PreferenceManager;
import android.util.Log;
import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;
import red.tel.chat.generated_protobuf.Haber;
import android.support.v4.content.LocalBroadcastManager;

public class Model {

    private static final String TAG = "Model";
    private static final String USERNAME = "username";

    private static List<String> contacts = new ArrayList<>();

    public static List<String> getContacts() {
        return contacts;
    }

    public static String getUsername() {
        return ChatApplication.getSharedPreferences().getString(USERNAME, null);
    }

    public static void setUsername(String username) {
        ChatApplication.getSharedPreferences().edit().putString(USERNAME, username).apply();
    }

    static void incoming(Haber haber) {
        switch (haber.which) {
            case CONTACTS:
                contacts = haber.contacts.stream().map(contact -> contact.name).collect(Collectors.toList());
                Intent intent = new Intent("custom-event-name");
                Context context = ChatApplication.getContext().getApplicationContext();
                LocalBroadcastManager.getInstance(context).sendBroadcast(intent);
                break;
            default:
                Log.e(TAG, "Did not handle incoming " + haber.which);
        }
    }
}
