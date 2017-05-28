package red.tel.chat;

import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.preference.PreferenceManager;
import android.util.Log;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import red.tel.chat.generated_protobuf.Haber;
import android.support.v4.content.LocalBroadcastManager;
import red.tel.chat.generated_protobuf.Contact;

public class Model {

    private static final String TAG = "Model";
    private static final String USERNAME = "username";

    private static Map<String, Contact> roster = new HashMap<>();

    public static List<String> getContacts() {
        return roster.values().stream().map(contact -> contact.name).collect(Collectors.toList());
    }

    private static SharedPreferences getSharedPreferences() {
        return PreferenceManager.getDefaultSharedPreferences(ChatApplication.getContext());
    }

    public static String getUsername() {
        return getSharedPreferences().getString(USERNAME, null);
    }

    public static void setUsername(String username) {
        getSharedPreferences().edit().putString(USERNAME, username).apply();
    }

    // from Backend
    static void incoming(Haber haber) {
        switch (haber.which) {
            case CONTACTS:
                roster = haber.contacts.stream().collect(Collectors.toMap(c -> c.name, c -> c));
                break;
            default:
                Log.e(TAG, "Did not handle incoming " + haber.which);
                return;
        }

        Intent intent = new Intent(haber.which.toString());
        Context context = ChatApplication.getContext().getApplicationContext();
        LocalBroadcastManager.getInstance(context).sendBroadcast(intent);
    }

    public static void setContacts(List<String> names) {
        roster = names.stream().collect(Collectors.toMap(name -> name, name ->
                roster.containsKey(name) ?
                        roster.get(name) :
                        new Contact.Builder().name(name).build()));
        Backend.sendContacts(new ArrayList<>(roster.values()));
    }
}