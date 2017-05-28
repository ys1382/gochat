package red.tel.chat.ui;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Bundle;
import android.support.annotation.NonNull;
import android.support.design.widget.FloatingActionButton;
import android.support.v4.content.LocalBroadcastManager;
import android.support.v7.app.AlertDialog;
import android.support.v7.app.AppCompatActivity;
import android.support.v7.widget.RecyclerView;
import android.support.v7.widget.Toolbar;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageButton;
import android.widget.TextView;
import android.widget.EditText;
import java.util.ArrayList;
import java.util.List;

import red.tel.chat.Model;
import red.tel.chat.R;
import red.tel.chat.generated_protobuf.Haber;

/**
 * An activity representing a list of Items. This activity has different presentations for handset
 * and tablet-size devices. On handsets, the activity presents a list of items, which when touched,
 * lead to a {@link ItemDetailActivity} representing item details. On tablets, the activity presents
 * the list of items and item details side-by-side using two vertical panes.
 */
public class ItemListActivity extends AppCompatActivity {

    private static final String TAG = "ItemListActivity";
    private boolean isTwoPane; // Whether or not the activity is in two-pane mode, i.e. running on a tablet device.
    private SimpleItemRecyclerViewAdapter recyclerViewAdapter;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_item_list);

        Toolbar toolbar = (Toolbar) findViewById(R.id.toolbar);
        setSupportActionBar(toolbar);
        toolbar.setTitle(getTitle());

//        FloatingActionButton fab = (FloatingActionButton) findViewById(R.id.fab);
//        fab.setOnClickListener((View view) -> onClickAdd());

        View recyclerView = findViewById(R.id.item_list);
        assert recyclerView != null;
        setupRecyclerView((RecyclerView) recyclerView);

        if (findViewById(R.id.item_detail_container) != null) {
            // The detail container view will be present only in the large-screen layouts (res/values-w900dp).
            // If this view is present, then the activity should be in two-pane mode.
            isTwoPane = true;
        }
    }

    private void setupRecyclerView(@NonNull RecyclerView recyclerView) {
        this.recyclerViewAdapter = new SimpleItemRecyclerViewAdapter();
        recyclerView.setAdapter(this.recyclerViewAdapter);
    }

    public class SimpleItemRecyclerViewAdapter extends RecyclerView.Adapter<SimpleItemRecyclerViewAdapter.ViewHolder> {

        private List<String> values = new ArrayList<>();

        @Override
        public ViewHolder onCreateViewHolder(ViewGroup parent, int viewType) {
            View view = LayoutInflater.from(parent.getContext())
                    .inflate(R.layout.item_list_content, parent, false);
            return new ViewHolder(view);
        }

        @Override
        public void onBindViewHolder(final ViewHolder holder, int position) {
            holder.dummyItem = this.values.get(position);
            holder.contactName.setText(this.values.get(position));

            holder.view.setOnClickListener((View v) -> {
                if (isTwoPane) {
                    Bundle arguments = new Bundle();
                    arguments.putString(ItemDetailFragment.ARG_ITEM_ID, holder.dummyItem);
                    ItemDetailFragment fragment = new ItemDetailFragment();
                    fragment.setArguments(arguments);
                    getSupportFragmentManager().beginTransaction()
                            .replace(R.id.item_detail_container, fragment)
                            .commit();
                } else {
                    Context context = v.getContext();
                    Intent intent = new Intent(context, ItemDetailActivity.class);
                    intent.putExtra(ItemDetailFragment.ARG_ITEM_ID, holder.dummyItem);
                    context.startActivity(intent);
                }
            });
        }

        @Override
        public int getItemCount() {
            return values.size();
        }

        class ViewHolder extends RecyclerView.ViewHolder {
            final View view;
            final TextView contactName;
            final ImageButton deleteContact;
            String dummyItem;

            ViewHolder(View view) {
                super(view);
                this.view = view;
                contactName = (TextView) view.findViewById(R.id.contactName);
                deleteContact = (ImageButton) view.findViewById(R.id.deleteContact);
                view.setOnLongClickListener(v -> {
                    deleteContact.setVisibility(View.VISIBLE);
                    return true;
                });
            }

        }
    }

    public void onClickDelete(View v) {
        AlertDialog.Builder alert = new AlertDialog.Builder(this);
        alert.setTitle(R.string.del_contact_title);
        alert.setMessage(R.string.del_contact_message);

        alert.setPositiveButton(R.string.ok, (dialog, whichButton) -> {
//            recyclerViewAdapter.values.remove(contactName.getText().toString());
            Model.setContacts(recyclerViewAdapter.values);
            recyclerViewAdapter.notifyDataSetChanged();
        });

        alert.setNegativeButton(R.string.cancel, (dialog, whichButton) -> dialog.cancel());
        alert.create().show();
    }

    protected void onResume() {
        super.onResume();
        IntentFilter intentFilter = new IntentFilter(Haber.Which.CONTACTS.toString());
        LocalBroadcastManager.getInstance(this).registerReceiver(onNotice, intentFilter);
    }

    protected void onPause() {
        super.onPause();
        LocalBroadcastManager.getInstance(this).unregisterReceiver(onNotice);
    }

    private BroadcastReceiver onNotice = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            recyclerViewAdapter.values = Model.getContacts();
            recyclerViewAdapter.notifyDataSetChanged();
        }
    };

    public void onClickAdd(View v) {
        AlertDialog.Builder alert = new AlertDialog.Builder(this);
        alert.setTitle(R.string.add_contact_title);
        alert.setMessage(R.string.add_contact_message);

        final EditText input = new EditText(this);
        alert.setView(input);

        alert.setPositiveButton(R.string.ok, (dialog, whichButton) -> {
            String name = input.getEditableText().toString();
            recyclerViewAdapter.values.add(name);
            Model.setContacts(recyclerViewAdapter.values);
            recyclerViewAdapter.notifyDataSetChanged();
        });

        alert.setNegativeButton(R.string.cancel, (dialog, whichButton) -> dialog.cancel());
        alert.create().show();
    }
}