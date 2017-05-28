package red.tel.chat;

import android.app.IntentService;
import android.content.Intent;
import android.util.Log;

import java.io.IOException;
import java.util.List;

import red.tel.chat.generated_protobuf.Contact;
import red.tel.chat.generated_protobuf.Haber;
import red.tel.chat.generated_protobuf.Login;

import static red.tel.chat.generated_protobuf.Haber.Which.CONTACTS;
import static red.tel.chat.generated_protobuf.Haber.Which.LOGIN;

// shuttles data between Network and Model
public class Backend extends IntentService {

    private static final String TAG = "Backend";
    private static Backend shared;
    public Backend() {
        super(TAG);
    }
    Network network;

    @Override
    protected void onHandleIntent(Intent workIntent) {
        shared = this;
        network = new Network();
    }

    // receive from Network
    static void incoming(byte[] binary) {
        try {
            Haber haber = Haber.ADAPTER.decode(binary);
            Model.incoming(haber);
        } catch (IOException ioException) {
            Log.e(TAG, ioException.getLocalizedMessage());
        }
    }

    public void send(Haber haber) {
        byte[] bytes = Haber.ADAPTER.encode(haber);
        network.send(bytes);
    }

    // send to Network

    public interface Result {
        void done(Boolean success);
    }

    public static void login(String username, Backend.Result result) {
        Login login = new Login.Builder().username(username).build();
        Haber haber = new Haber.Builder().which(LOGIN).login(login).build();
        shared.send(haber);
        result.done(true);
    }

    public static void sendContacts(List<Contact> contacts) {
        Haber haber = new Haber.Builder().which(CONTACTS).contacts(contacts).build();
        shared.send(haber);
    }
}