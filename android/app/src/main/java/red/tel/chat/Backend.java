package red.tel.chat;

import android.app.IntentService;
import android.content.Intent;
import android.util.Log;

import java.io.IOException;
import java.util.List;

import red.tel.chat.generated_protobuf.Contact;
import red.tel.chat.generated_protobuf.Haber;
import red.tel.chat.generated_protobuf.Login;
import red.tel.chat.generated_protobuf.Text;
import red.tel.chat.ui.ItemListActivity;

import static red.tel.chat.generated_protobuf.Haber.Which.CONTACTS;
import static red.tel.chat.generated_protobuf.Haber.Which.LOGIN;
import static red.tel.chat.generated_protobuf.Haber.Which.TEXT;

// shuttles data between Network and Model
public class Backend extends IntentService {

    private static final String TAG = "Backend";
    private static Backend shared;
    public Backend() {
        super(TAG);
    }
    Network network;
    static String sessionId;

    @Override
    protected void onHandleIntent(Intent workIntent) {
        shared = this;
        network = new Network();

        EventBus.listenFor(this, EventBus.Event.CONNECTED, () -> {
            String username = Model.getUsername();
            if (username != null) {
                Backend.login(username);
            }
        });
    }

    // receive from Network
    static void incoming(byte[] binary) {
        try {
            Haber haber = Haber.ADAPTER.decode(binary);
            Log.d(TAG, "incoming " + haber.which);

            if (haber.sessionId != null) {
                sessionId = haber.sessionId;
                EventBus.announce(EventBus.Event.AUTHENTICATED);
            }
            Model.incoming(haber);
        } catch (IOException ioException) {
            Log.e(TAG, ioException.getLocalizedMessage());
        }
    }

    public void send(Haber.Builder haber) {
        Log.d(TAG, "send " + haber.which.getValue());
        haber.sessionId = sessionId;
        byte[] bytes = Haber.ADAPTER.encode(haber.build());
        network.send(bytes);
    }

    // send to Network

    public static void login(String username) {
        Login login = new Login.Builder().username(username).build();
        Haber.Builder haber = new Haber.Builder().which(LOGIN).login(login);
        shared.send(haber);
    }

    public static void sendContacts(List<Contact> contacts) {
        Haber.Builder haber = new Haber.Builder().which(CONTACTS).contacts(contacts);
        shared.send(haber);
    }

    public static void sendText(String recipient, String message) {
        Text text = new Text.Builder().body(message).build();
        Haber.Builder haber = new Haber.Builder().which(TEXT).text(text).to(recipient);
        shared.send(haber);
    }
}