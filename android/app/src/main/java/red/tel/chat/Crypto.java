package red.tel.chat;

import android.util.Log;

import com.cossacklabs.themis.ISessionCallbacks;
import com.cossacklabs.themis.KeyGenerationException;
import com.cossacklabs.themis.Keypair;
import com.cossacklabs.themis.KeypairGenerator;
import com.cossacklabs.themis.PrivateKey;
import com.cossacklabs.themis.PublicKey;
import com.cossacklabs.themis.SecureCell;
import com.cossacklabs.themis.SecureCellData;
import com.cossacklabs.themis.SecureSession;

import java.io.UnsupportedEncodingException;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Map;

class Crypto {

    private static final String TAG = "Crypto";
    private SecureCell cell;
    private String clientId;
    private PrivateKey clientPrivateKey;
    private PublicKey clientPublicKey;
    private Map<String, Peer> peers = new HashMap<>();

    Crypto(String username, String password) throws UnsupportedEncodingException, KeyGenerationException {
        clientId = username;
        cell = new SecureCell(password);
        Keypair pair = KeypairGenerator.generateKeypair();
        clientPrivateKey = pair.getPrivateKey();
        clientPublicKey = pair.getPublicKey();
    }

    private Peer getPeer(String peerId) {
        if (!peers.containsKey(peerId)) {
            Peer peer = new Peer(peerId);
            peers.put(peerId, peer);
        }
        return peers.get(peerId);
    }

    Boolean isSessionEstablishedFor(String peerId) {
        Peer peer = getPeer(peerId);
        if (peer.status == Status.BEGUN) {
            peer.sendPublicKey(false);
        }
        return peer.status == Status.SESSION_ESTABLISHED;
    }

    byte[] keyDerivationEncrypt(byte[] data) throws Exception {
        SecureCellData cellData = cell.protect(TAG, data);
        return cellData.getProtectedData();
    }

    byte[] keyDerivationDecrypt(byte[] data) throws Exception {
        SecureCellData cellData = new SecureCellData(data, null);
        return cell.unprotect(TAG, cellData);
    }

    void setPublicKey(byte[] key, String peerId, Boolean isResponse) throws Exception {
        Peer peer = getPeer(peerId);
        peer.setServerPublicKey(key, isResponse);
    }

    void onReceivePayload(byte[] payload, String peerId) throws Exception {
        getPeer(peerId).didReceive(payload);
    }

    byte[] encrypt(byte[] data, String peerId) throws Exception {
        return getPeer(peerId).encrypt(data);
    }

    /////// Transport

    private class Transport implements ISessionCallbacks {

        private String peerId;
        private PublicKey serverPublicKey;

        void setupKeys(String peerId, byte[] serverPublicKey) {
            this.peerId = peerId;
            this.serverPublicKey = new PublicKey(serverPublicKey);
        }

        @Override
        public PublicKey getPublicKeyForId(SecureSession session, byte[] id) {
            if (Arrays.equals(id, peerId.getBytes())) {
                return serverPublicKey;
            } else {
                Log.e(TAG, "key id mismatch");
                return null;
            }
        }

        @Override
        public void stateChanged(SecureSession session) {
            // todo: update UI: for example, draw a nice padlock indicating to the user that his/her communication is now secured
            Log.d(TAG, "Peer " + peerId + " state changed to " + session);
        }
    }

    /////// Peer

    private enum Status {
        BEGUN,
        PUBLIC_KEY_SENT,
        SESSION_ESTABLISHED
    }

    private class Peer {

        Status status  = Status.BEGUN;

        private Transport transport = new Transport();
        private SecureSession session;
        private String peerId;

        Peer(String peerId) {
            this.peerId = peerId;
        }

        void setServerPublicKey(byte[] key, Boolean isResponse) throws Exception {
            transport.setupKeys(peerId, key);
            session = new SecureSession(clientId, clientPrivateKey, transport);
            if (isResponse) {
                connect();
            } else {
                sendPublicKey(true);
            }
        }

        private void sendPublicKey(Boolean isResponse) {
            status = Status.PUBLIC_KEY_SENT;
            Backend.shared().sendPublicKey(clientPublicKey.toByteArray(), peerId, isResponse);
        }

        private void connect() {
            try {
                byte[] connectRequest = session.generateConnectRequest();
                Backend.shared().sendHandshake(connectRequest, peerId);
            } catch (Exception exception) {
                Log.e(TAG, exception.getLocalizedMessage());
            }
        }

        void didReceive(byte[] receiveBuffer) throws Exception {
            SecureSession.UnwrapResult result = session.unwrap(receiveBuffer);
            if (session.isEstablished()) {
                status = Status.SESSION_ESTABLISHED;
                Backend.shared().handshook(peerId);        }
            switch (result.getDataType()) {
                case USER_DATA:
                    // this is the actual data that was encrypted by your peer using SecureSession.wrap
                    // process the data according to your application's flow for incoming data
                    Backend.shared().onReceiveData(result.getData());
                    break;
                case PROTOCOL_DATA:
                    // this is the internal Secure Session protocol data. An opaque response was generated, just send it to your peer
                    // send the data to your peer as is
                    Backend.shared().sendHandshake(result.getData(), peerId);
                    break;
                case NO_DATA:
                    // this is the internal Secure Session protocol data, but no response is needed (this usually takes place on the client side when protocol negotiation completes)
                    // do nothing
                    break;
            }
        }

        byte[] encrypt(byte[] data) throws Exception {
            return session.wrap(data);
        }
    }
}
