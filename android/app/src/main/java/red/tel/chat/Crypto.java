package red.tel.chat;

import com.cossacklabs.themis.Keypair;
import com.cossacklabs.themis.KeypairGenerator;
import com.cossacklabs.themis.PrivateKey;
import com.cossacklabs.themis.PublicKey;

class Crypto {

    Crypto() {
        try {
            Keypair pair = KeypairGenerator.generateKeypair();
            PrivateKey privateKey = pair.getPrivateKey();
            PublicKey publicKey = pair.getPublicKey();
        } catch (Exception exception) {

        }
    }
}
