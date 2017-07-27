package red.tel.chat.ui;

import android.support.v7.app.AppCompatActivity;
import android.content.Context;
import android.support.design.widget.Snackbar;

public class BaseActivity extends AppCompatActivity {

    private static BaseActivity current;

    @Override
    protected void onResume() {
        super.onResume();
        current = this;
    }

    @Override
    protected void onPause() {
        super.onPause();
        current = null;
    }

    protected android.view.View getView() {
        return getWindow().getDecorView().getRootView();
    }

    public static void snackbar(String message) {
        Snackbar snackbar = Snackbar.make(current.getView(), message, Snackbar.LENGTH_LONG);
        snackbar.show();
    }

    public static Context getCurrentContext() {
        return current;
    }
}
