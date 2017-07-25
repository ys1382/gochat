package red.tel.chat;

import com.cossacklabs.themis.KeyGenerationException;
import com.cossacklabs.themis.Keypair;
import com.cossacklabs.themis.KeypairGenerator;
import com.cossacklabs.themis.NullArgumentException;
import com.cossacklabs.themis.PrivateKey;
import com.cossacklabs.themis.PublicKey;
import com.cossacklabs.themis.SecureCell;
import com.cossacklabs.themis.SecureCellData;
import com.cossacklabs.themis.SecureCellException;

import java.io.UnsupportedEncodingException;

class Crypto {

    private SecureCell cell;
    private PrivateKey privateKey;
    private PublicKey publicKey;
    private static final String nullContext = null;


    Crypto(String password) throws UnsupportedEncodingException, KeyGenerationException {
        SecureCell cell = new SecureCell(password);

        Keypair pair = KeypairGenerator.generateKeypair();
        privateKey = pair.getPrivateKey();
        publicKey = pair.getPublicKey();
    }

    byte[] keyDerivationEncrypt(byte[] data) throws Exception {
        SecureCellData cellData = cell.protect(nullContext, data);
        return cellData.getProtectedData();
    }

    byte[] keyDerivationDecrypt(byte[] data) throws Exception {
        SecureCellData cellData = new SecureCellData(data, null);
        return cell.unprotect(nullContext, cellData);
    }
}
