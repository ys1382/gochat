package red.tel.chat;

import android.content.SharedPreferences;
import android.preference.PreferenceManager;
import android.util.Log;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import red.tel.chat.EventBus.Event;
import red.tel.chat.generated_protobuf.Wire;
import red.tel.chat.generated_protobuf.Voip;
import red.tel.chat.generated_protobuf.Contact;
import red.tel.chat.generated_protobuf.Text;

public class Model {

    private static final String TAG = "Model";
    private static final String TEXTS = "texts";
    private static final String USERNAME = "username";
    private static final String PASSWORD = "password";
    private Map<String, Contact> roster = new HashMap<>();
    private List<Text> texts = new ArrayList<>();
    private static Model instance;

    public static Model shared() {
        if (instance == null) {
            instance = new Model();
        }
        return instance;
    }

    public List<String> getContacts() {
        return roster.values().stream().map(contact -> contact.name).collect(Collectors.toList());
    }

    public Boolean isOnline(String name) {
        Contact contact = roster.get(name);
        return contact.online != null && contact.online;
    }

    public List<Text> getTexts() {
        return texts;
    }

    private SharedPreferences getSharedPreferences() {
        return PreferenceManager.getDefaultSharedPreferences(ChatApp.getContext());
    }

    String getUsername() {
        return getSharedPreferences().getString(USERNAME, null);
    }

    String getPassword() {
        return getSharedPreferences().getString(PASSWORD, null);
    }

    public void setUsername(String username) {
        getSharedPreferences().edit().putString(USERNAME, username).apply();
    }

    public void setPassword(String username) {
        getSharedPreferences().edit().putString(PASSWORD, username).apply();
    }

    void incomingFromServer(Wire wire) {
        switch (wire.which) {
            case CONTACTS:
                roster = wire.contacts.stream().collect(Collectors.toMap(c -> c.name, c -> c));
                EventBus.announce(Event.CONTACTS);
                break;
            default:
                Log.e(TAG, "Did not handle incoming " + wire.which);
        }
    }

    void incomingFromPeer(Voip voip, String peerId) {
        switch (voip.which) {
            case TEXT:
                Text text = new Text.Builder().body(voip.payload).to(getUsername()).from(peerId).build();
                texts.add(text);
                storeTexts();
                Log.d(TAG, "text " + voip.payload.utf8() + ", texts.size = " + texts.size());
                EventBus.announce(Event.TEXT);
                break;
            default:
                Log.e(TAG, "Did not handle incoming " + voip.which);
        }
    }

    private void storeTexts() {
        byte[] data = new Voip.Builder().textStorage(texts).build().encode();
        Backend.shared().sendStore(TEXTS, data);
    }

    void onReceiveStore(String key, byte[] value) throws Exception {
        if (key.equals(TEXTS)) {
            Voip parsed = Voip.ADAPTER.decode(value);
            texts = parsed.textStorage;
            EventBus.announce(Event.TEXT);
        } else {
            Log.e(TAG, "unsupported key " + key);
        }
    }

    public void setContacts(List<String> names) {
        roster = names.stream().collect(Collectors.toMap(name -> name, name ->
                roster.containsKey(name) ?
                        roster.get(name) :
                        new Contact.Builder().name(name).build()));
        Backend.shared().sendContacts(new ArrayList<>(roster.values()));
    }
}
