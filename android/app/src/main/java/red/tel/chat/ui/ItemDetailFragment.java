package red.tel.chat.ui;

import android.app.Activity;
import android.os.Bundle;
import android.support.design.widget.CollapsingToolbarLayout;
import android.support.v4.app.Fragment;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.EditText;
import android.widget.ImageButton;
import android.widget.TextView;

import java.util.Locale;

import red.tel.chat.generated_protobuf.Text;
import red.tel.chat.Backend;
import red.tel.chat.EventBus;
import red.tel.chat.Model;
import red.tel.chat.R;

/**
 * A fragment representing a single Item detail screen.
 * This fragment is either contained in a {@link ItemListActivity}
 * in two-pane mode (on tablets) or a {@link ItemDetailActivity}
 * on handsets.
 */
public class ItemDetailFragment extends Fragment {

    private static final String TAG = "ItemDetailFragment";

    // The fragment argument representing the item ID that this fragment represents.
    public static final String ARG_ITEM_ID = "item_id";

    private String whom;

    // Mandatory empty constructor for the fragment manager to instantiate the fragment (e.g. upon
    // screen orientation changes).
    public ItemDetailFragment() {}

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        if (getArguments().containsKey(ARG_ITEM_ID)) {
            // Load the dummy content specified by the fragment arguments. In a real-world scenario,
            // use a Loader to load content from a content provider.
            whom = getArguments().getString(ARG_ITEM_ID);

            Activity activity = this.getActivity();
            CollapsingToolbarLayout appBarLayout = (CollapsingToolbarLayout) activity.findViewById(R.id.toolbar_layout);
            if (appBarLayout != null) {
                appBarLayout.setTitle(whom);
            }
        }
    }

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        View rootView = inflater.inflate(R.layout.item_detail, container, false);
        getActivity().setTitle(whom);

        EditText messageEdit = (EditText) rootView.findViewById(R.id.messageEdit);
        ImageButton messageSend = (ImageButton) rootView.findViewById(R.id.chatSendButton);
        messageSend.setOnClickListener(v -> Backend.shared().sendText(messageEdit.getText().toString(), whom));

        EventBus.listenFor(getActivity(), EventBus.Event.TEXT, () -> {
            TextView textView = (TextView) rootView.findViewById(R.id.messagesContainer);
            StringBuilder texts = new StringBuilder();
            for (Text text: Model.shared().getTexts()) {
                String line = String.format(Locale.US,"%1$s: %2$s\n", text.from, text.body);
                texts.append(line);
            }
            Log.d(TAG, "texts = " + texts);
            textView.setText(texts);
        });

        return rootView;
    }
}
