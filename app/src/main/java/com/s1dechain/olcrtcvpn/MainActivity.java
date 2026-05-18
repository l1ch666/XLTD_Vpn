package com.s1dechain.olcrtcvpn;

import android.app.Activity;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.net.Uri;
import android.net.VpnService;
import android.os.Build;
import android.os.Bundle;
import android.os.PowerManager;
import android.provider.Settings;
import android.text.InputType;
import android.text.TextUtils;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.view.inputmethod.InputMethodManager;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import java.util.ArrayList;
import java.util.List;

public final class MainActivity extends Activity {
    private static final int VPN_REQUEST_CODE = 1201;
    private static final String PREFS = "main";
    private static final String KEY_LINK = "last_link";
    private static final String KEY_PROFILE_IDS = "profile_ids";
    private static final String KEY_SELECTED_PROFILE_ID = "selected_profile_id";

    private static final int STATE_DISCONNECTED = 0;
    private static final int STATE_CONNECTING = 1;
    private static final int STATE_CONNECTED = 2;

    private EditText linkInput;
    private EditText profileNameInput;
    private LinearLayout editorCard;
    private TextView editorTitle;
    private TextView editorDeleteButton;
    private TextView statusView;
    private TextView detailsView;
    private TextView stateChip;
    private TextView heroSubtitle;
    private TextView toggleButton;
    private LinearLayout profilesList;

    private String pendingLink;
    private String selectedProfileId;
    private String editingProfileId;
    private int connectionState = STATE_DISCONNECTED;
    private boolean statusReceiverRegistered = false;

    private final BroadcastReceiver statusReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            if (OlcVpnService.ACTION_STATUS.equals(intent.getAction())) {
                String status = intent.getStringExtra(OlcVpnService.EXTRA_STATUS);
                if (status != null) applyServiceStatus(status);
            }
        }
    };

    private static final class Profile {
        final String id;
        final String name;
        final String link;
        final String carrier;
        final String transport;

        Profile(String id, String name, String link, String carrier, String transport) {
            this.id = id;
            this.name = name;
            this.link = link;
            this.carrier = carrier;
            this.transport = transport;
        }
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        buildUi();
        handleIncomingIntent(getIntent());
    }

    @Override
    protected void onStart() {
        super.onStart();
        registerStatusReceiver();
        String lastStatus = OlcVpnService.getLastStatusSnapshot();
        if (!TextUtils.isEmpty(lastStatus)) applyServiceStatus(lastStatus);
        refreshProfilesList();
    }

    @Override
    protected void onStop() {
        unregisterStatusReceiver();
        super.onStop();
    }

    private void registerStatusReceiver() {
        if (statusReceiverRegistered) return;
        IntentFilter filter = new IntentFilter(OlcVpnService.ACTION_STATUS);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(statusReceiver, filter, Context.RECEIVER_NOT_EXPORTED);
        } else {
            registerReceiver(statusReceiver, filter);
        }
        statusReceiverRegistered = true;
    }

    private void unregisterStatusReceiver() {
        if (!statusReceiverRegistered) return;
        try {
            unregisterReceiver(statusReceiver);
        } catch (Exception ignored) {
        } finally {
            statusReceiverRegistered = false;
        }
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        handleIncomingIntent(intent);
    }

    private void buildUi() {
        SharedPreferences prefs = getSharedPreferences(PREFS, MODE_PRIVATE);
        selectedProfileId = prefs.getString(KEY_SELECTED_PROFILE_ID, "");

        ScrollView scroll = new ScrollView(this);
        scroll.setFillViewport(true);
        scroll.setBackgroundColor(Color.parseColor("#F5F6F8"));

        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(dp(20), dp(20), dp(20), dp(24));
        scroll.addView(root, new ScrollView.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
        ));

        root.addView(buildHeroCard(), lpMatchWrap());
        root.addView(buildProfilesCard(), lpMatchWrap());

        editorCard = buildEditorCard();
        editorCard.setVisibility(View.GONE);
        root.addView(editorCard, lpMatchWrap());

        root.addView(buildConnectionCard(), lpMatchWrap());
        root.addView(buildDetailsCard(), lpMatchWrap());

        setContentView(scroll);

        boolean comboReady = OlcMobileBridge.isAvailable() && Tun2SocksMobileBridge.isAvailable();
        setStatus(comboReady ? "Готов к подключению." : "Core не найден. Собери combo AAR и пересобери APK.");
        applyConnectionState(STATE_DISCONNECTED, comboReady ? "Готов к подключению" : "Нужно собрать combo AAR");
        refreshProfilesList();
    }

    private LinearLayout buildHeroCard() {
        LinearLayout heroCard = cardLayout();
        heroCard.setPadding(dp(20), dp(20), dp(20), dp(20));

        LinearLayout heroTop = new LinearLayout(this);
        heroTop.setOrientation(LinearLayout.HORIZONTAL);
        heroTop.setGravity(Gravity.CENTER_VERTICAL);

        TextView logoBubble = new TextView(this);
        logoBubble.setText("o");
        logoBubble.setTextColor(Color.WHITE);
        logoBubble.setTypeface(Typeface.DEFAULT_BOLD);
        logoBubble.setTextSize(TypedValue.COMPLEX_UNIT_SP, 22);
        logoBubble.setGravity(Gravity.CENTER);
        logoBubble.setBackground(roundedDrawable("#111111", 18, null, 0));
        heroTop.addView(logoBubble, squareLp(dp(44)));

        LinearLayout heroTextWrap = new LinearLayout(this);
        heroTextWrap.setOrientation(LinearLayout.VERTICAL);
        LinearLayout.LayoutParams heroTextLp = new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f);
        heroTextLp.setMargins(dp(14), 0, 0, 0);

        TextView title = new TextView(this);
        title.setText("olcRTC VPN");
        title.setTextColor(Color.parseColor("#111111"));
        title.setTextSize(TypedValue.COMPLEX_UNIT_SP, 26);
        title.setTypeface(Typeface.DEFAULT_BOLD);
        heroTextWrap.addView(title, lpMatchWrap());

        heroSubtitle = new TextView(this);
        heroSubtitle.setText("Готов к подключению");
        heroSubtitle.setTextColor(Color.parseColor("#6F737B"));
        heroSubtitle.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14);
        heroTextWrap.addView(heroSubtitle, lpMatchWrapNoMargin());

        heroTop.addView(heroTextWrap, heroTextLp);
        heroCard.addView(heroTop, lpMatchWrapNoMargin());

        TextView heroCaption = new TextView(this);
        heroCaption.setText("Выбери профиль и подключайся одной кнопкой.");
        heroCaption.setTextColor(Color.parseColor("#7A7F87"));
        heroCaption.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13);
        heroCaption.setPadding(0, dp(16), 0, 0);
        heroCard.addView(heroCaption, lpMatchWrapNoMargin());

        return heroCard;
    }

    private LinearLayout buildProfilesCard() {
        LinearLayout profilesCard = cardLayout();
        profilesCard.setPadding(dp(18), dp(18), dp(18), dp(18));

        LinearLayout header = new LinearLayout(this);
        header.setOrientation(LinearLayout.HORIZONTAL);
        header.setGravity(Gravity.CENTER_VERTICAL);

        TextView profilesTitle = sectionLabel("Configurations");
        header.addView(profilesTitle, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f));

        TextView addButton = smallRoundButton("+");
        addButton.setOnClickListener(v -> openNewProfileEditor(""));
        header.addView(addButton, squareLp(dp(36)));

        profilesCard.addView(header, lpMatchWrapNoMargin());

        profilesList = new LinearLayout(this);
        profilesList.setOrientation(LinearLayout.VERTICAL);
        profilesList.setPadding(0, dp(10), 0, 0);
        profilesCard.addView(profilesList, lpMatchWrapNoMargin());

        return profilesCard;
    }

    private LinearLayout buildEditorCard() {
        LinearLayout card = cardLayout();
        card.setPadding(dp(18), dp(18), dp(18), dp(18));

        LinearLayout header = new LinearLayout(this);
        header.setOrientation(LinearLayout.HORIZONTAL);
        header.setGravity(Gravity.CENTER_VERTICAL);

        editorTitle = sectionLabel("Profile settings");
        header.addView(editorTitle, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f));

        TextView close = smallRoundButton("×");
        close.setOnClickListener(v -> closeProfileEditor());
        header.addView(close, squareLp(dp(36)));
        card.addView(header, lpMatchWrapNoMargin());

        profileNameInput = new EditText(this);
        profileNameInput.setSingleLine(true);
        profileNameInput.setHint("Название профиля, можно пустым");
        profileNameInput.setTextColor(Color.parseColor("#111111"));
        profileNameInput.setHintTextColor(Color.parseColor("#A0A5AE"));
        profileNameInput.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14);
        profileNameInput.setPadding(dp(16), dp(13), dp(16), dp(13));
        profileNameInput.setBackground(roundedDrawable("#F5F6F8", 18, "#E7E9EE", 1));
        profileNameInput.setCursorVisible(false);
        profileNameInput.setOnFocusChangeListener((v, hasFocus) -> profileNameInput.setCursorVisible(hasFocus));
        card.addView(profileNameInput, lpMatchWrap());

        linkInput = new EditText(this);
        linkInput.setMinLines(5);
        linkInput.setGravity(Gravity.TOP | Gravity.START);
        linkInput.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_MULTI_LINE | InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS);
        linkInput.setHint("olcrtc://wbstream?datachannel@room#64hex...%default$direct\nили vp8: olcrtc://telemost?vp8channel<vp8-fps=25&vp8-batch=1>@room#key%default$direct");
        linkInput.setTextColor(Color.parseColor("#111111"));
        linkInput.setHintTextColor(Color.parseColor("#A0A5AE"));
        linkInput.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14);
        linkInput.setPadding(dp(16), dp(16), dp(16), dp(16));
        linkInput.setBackground(roundedDrawable("#F5F6F8", 18, "#E7E9EE", 1));
        linkInput.setCursorVisible(false);
        linkInput.setOnFocusChangeListener((v, hasFocus) -> linkInput.setCursorVisible(hasFocus));
        card.addView(linkInput, lpMatchWrap());

        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);

        TextView save = actionButton("Сохранить");
        save.setOnClickListener(v -> saveEditorProfile());
        row.addView(save, rowTextButtonLp(1f));

        editorDeleteButton = actionButton("Удалить");
        editorDeleteButton.setOnClickListener(v -> deleteEditingProfile());
        row.addView(editorDeleteButton, rowTextButtonLp(0.55f));

        card.addView(row, lpMatchWrapNoMargin());

        return card;
    }

    private LinearLayout buildConnectionCard() {
        LinearLayout controlCard = cardLayout();
        controlCard.setPadding(dp(18), dp(18), dp(18), dp(18));

        LinearLayout statusRow = new LinearLayout(this);
        statusRow.setOrientation(LinearLayout.HORIZONTAL);
        statusRow.setGravity(Gravity.CENTER_VERTICAL);
        statusRow.setPadding(0, 0, 0, dp(8));

        TextView connectionLabel = new TextView(this);
        connectionLabel.setText("Connection");
        connectionLabel.setTextColor(Color.parseColor("#6F737B"));
        connectionLabel.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13);
        statusRow.addView(connectionLabel, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f));

        stateChip = new TextView(this);
        stateChip.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12);
        stateChip.setTypeface(Typeface.DEFAULT_BOLD);
        stateChip.setPadding(dp(12), dp(8), dp(12), dp(8));
        stateChip.setGravity(Gravity.CENTER);
        statusRow.addView(stateChip, lpWrapWrapNoMargin());
        controlCard.addView(statusRow, lpMatchWrapNoMargin());

        toggleButton = primaryButton("Подключить");
        toggleButton.setOnClickListener(v -> onToggleClick());
        controlCard.addView(toggleButton, lpMatchWrap());

        TextView batteryButton = secondaryTextButton("Фон / энергосбережение");
        batteryButton.setOnClickListener(v -> requestBatteryOptimizationExemption());
        controlCard.addView(batteryButton, lpMatchWrap());

        statusView = new TextView(this);
        statusView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14);
        statusView.setTextColor(Color.parseColor("#363A42"));
        statusView.setPadding(0, dp(2), 0, 0);
        controlCard.addView(statusView, lpMatchWrapNoMargin());

        return controlCard;
    }

    private LinearLayout buildDetailsCard() {
        LinearLayout detailsCard = cardLayout();
        detailsCard.setPadding(dp(18), dp(18), dp(18), dp(18));

        TextView detailsTitle = sectionLabel("Details");
        detailsCard.addView(detailsTitle, lpMatchWrapNoMargin());

        detailsView = new TextView(this);
        detailsView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12);
        detailsView.setTextColor(Color.parseColor("#606772"));
        detailsView.setTypeface(Typeface.MONOSPACE);
        detailsView.setLineSpacing(0f, 1.1f);
        detailsView.setPadding(0, dp(8), 0, 0);
        detailsView.setText("Технические детали появятся после запуска.");
        detailsCard.addView(detailsView, lpMatchWrapNoMargin());

        return detailsCard;
    }

    private void handleIncomingIntent(Intent intent) {
        if (intent != null && intent.getDataString() != null) {
            openNewProfileEditor(intent.getDataString());
            setStatus("Ссылка получена. Сохрани её как профиль.");
            setDetails("Ссылка получена из Android intent.");
        }
    }

    private void onToggleClick() {
        hideEditorFocus();
        if (connectionState == STATE_CONNECTED || connectionState == STATE_CONNECTING) {
            stopVpn();
        } else {
            connect();
        }
    }

    private void connect() {
        try {
            Profile selected = getSelectedProfile();
            String link;
            if (selected != null) {
                link = selected.link;
            } else {
                SharedPreferences prefs = getSharedPreferences(PREFS, MODE_PRIVATE);
                link = prefs.getString(KEY_LINK, "");
            }

            if (link == null || link.trim().isEmpty()) {
                openNewProfileEditor("");
                applyConnectionState(STATE_DISCONNECTED, "Нет профиля");
                setStatus("Сначала добавь olcRTC-профиль.");
                return;
            }

            OlcUriParser.parse(link);
            getSharedPreferences(PREFS, MODE_PRIVATE).edit().putString(KEY_LINK, link).apply();
            pendingLink = link;
            applyConnectionState(STATE_CONNECTING, "Проверяю VPN-разрешение...");
            setStatus("Готовлю подключение.");

            Intent prepare = VpnService.prepare(this);
            if (prepare != null) {
                startActivityForResult(prepare, VPN_REQUEST_CODE);
            } else {
                startVpn(link);
            }
        } catch (Exception e) {
            applyConnectionState(STATE_DISCONNECTED, "Ошибка ссылки");
            setStatus(humanError("bad_link: " + e.getMessage()));
            setDetails("Parser error: " + safe(e.getMessage()));
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == VPN_REQUEST_CODE) {
            if (resultCode == RESULT_OK && pendingLink != null) {
                startVpn(pendingLink);
            } else {
                applyConnectionState(STATE_DISCONNECTED, "Разрешение не выдано");
                setStatus("VPN-разрешение не выдано.");
                setDetails("Android не разрешил создать VPN-подключение.");
            }
        }
    }

    private void startVpn(String link) {
        Intent intent = new Intent(this, OlcVpnService.class);
        intent.setAction(OlcVpnService.ACTION_START);
        intent.putExtra(OlcVpnService.EXTRA_LINK, link);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent);
        } else {
            startService(intent);
        }
        applyConnectionState(STATE_CONNECTING, "Подключение...");
        setStatus("Подключаюсь...");
        setDetails("Сервис запущен, жду статуса от olcRTC.");
    }

    private void stopVpn() {
        Intent intent = new Intent(this, OlcVpnService.class);
        intent.setAction(OlcVpnService.ACTION_STOP);
        startService(intent);
        applyConnectionState(STATE_DISCONNECTED, "Отключено");
        setStatus("Отключаю VPN...");
        setDetails("Остановка сервиса отправлена.");
    }

    private void openNewProfileEditor(String link) {
        editingProfileId = null;
        if (editorTitle != null) editorTitle.setText("New profile");
        if (profileNameInput != null) profileNameInput.setText("");
        if (linkInput != null) linkInput.setText(link == null ? "" : link);
        if (editorDeleteButton != null) editorDeleteButton.setVisibility(View.GONE);
        if (editorCard != null) editorCard.setVisibility(View.VISIBLE);
        setDetails("Вставь ссылку, при желании задай название и нажми «Сохранить».");
    }

    private void openEditProfileEditor(Profile profile) {
        if (profile == null) return;
        editingProfileId = profile.id;
        if (editorTitle != null) editorTitle.setText("Profile settings");
        if (profileNameInput != null) profileNameInput.setText(profile.name);
        if (linkInput != null) linkInput.setText(profile.link);
        if (editorDeleteButton != null) editorDeleteButton.setVisibility(View.VISIBLE);
        if (editorCard != null) editorCard.setVisibility(View.VISIBLE);
        setStatus("Редактирование профиля.");
        setDetails(profile.carrier + " / " + profile.transport + "\n" + shortLink(profile.link));
    }

    private void closeProfileEditor() {
        hideEditorFocus();
        if (editorCard != null) editorCard.setVisibility(View.GONE);
        editingProfileId = null;
    }

    private void saveEditorProfile() {
        hideEditorFocus();
        try {
            String link = linkInput == null ? "" : linkInput.getText().toString().trim();
            OlcConfig config = OlcUriParser.parse(link);

            SharedPreferences prefs = getSharedPreferences(PREFS, MODE_PRIVATE);
            String id = editingProfileId;
            if (id == null || id.trim().isEmpty()) {
                String existingId = findProfileIdByLink(link);
                id = existingId == null ? "p" + System.currentTimeMillis() : existingId;
            }

            String customName = profileNameInput == null ? "" : profileNameInput.getText().toString().trim();
            String name = customName.isEmpty() ? buildProfileName(config) : customName;

            prefs.edit()
                    .putString("profile_" + id + "_name", name)
                    .putString("profile_" + id + "_link", link)
                    .putString("profile_" + id + "_carrier", config.carrier)
                    .putString("profile_" + id + "_transport", config.transport)
                    .putString(KEY_SELECTED_PROFILE_ID, id)
                    .putString(KEY_LINK, link)
                    .apply();

            addProfileId(id);
            selectedProfileId = id;
            editingProfileId = id;
            refreshProfilesList();
            closeProfileEditor();
            setStatus("Профиль сохранён: " + name);
            setDetails(config.carrier + " / " + config.transport + (config.hasParams() ? " <" + config.paramsPretty() + ">" : "") + "\nclientId=" + config.clientId);
        } catch (Exception e) {
            setStatus(humanError("bad_link: " + e.getMessage()));
            setDetails("Profile save error: " + safe(e.getMessage()));
        }
    }

    private void deleteEditingProfile() {
        if (editingProfileId == null || editingProfileId.trim().isEmpty()) return;
        deleteProfile(editingProfileId);
        closeProfileEditor();
    }

    private void deleteProfile(String id) {
        SharedPreferences prefs = getSharedPreferences(PREFS, MODE_PRIVATE);
        prefs.edit()
                .remove("profile_" + id + "_name")
                .remove("profile_" + id + "_link")
                .remove("profile_" + id + "_carrier")
                .remove("profile_" + id + "_transport")
                .apply();

        removeProfileId(id);
        if (id.equals(selectedProfileId)) {
            selectedProfileId = "";
            prefs.edit().remove(KEY_SELECTED_PROFILE_ID).apply();
        }

        refreshProfilesList();
        setStatus("Профиль удалён.");
        setDetails("Выбери другой профиль или добавь новый.");
    }

    private void selectProfile(Profile profile) {
        if (profile == null) return;
        selectedProfileId = profile.id;
        getSharedPreferences(PREFS, MODE_PRIVATE).edit()
                .putString(KEY_SELECTED_PROFILE_ID, profile.id)
                .putString(KEY_LINK, profile.link)
                .apply();
        refreshProfilesList();
        setStatus("Выбран профиль: " + profile.name);
        setDetails(profile.carrier + " / " + profile.transport);
    }

    private void refreshProfilesList() {
        if (profilesList == null) return;
        profilesList.removeAllViews();

        List<Profile> profiles = loadProfiles();
        if (profiles.isEmpty()) {
            TextView empty = new TextView(this);
            empty.setText("Профилей пока нет. Нажми +, чтобы добавить olcRTC-ссылку.");
            empty.setTextColor(Color.parseColor("#7A7F87"));
            empty.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13);
            empty.setPadding(0, dp(6), 0, dp(2));
            profilesList.addView(empty, lpMatchWrapNoMargin());
            return;
        }

        for (Profile profile : profiles) {
            profilesList.addView(profileRow(profile), lpMatchWrap());
        }
    }

    private LinearLayout profileRow(Profile profile) {
        boolean selected = profile.id.equals(selectedProfileId);

        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setPadding(dp(14), dp(12), dp(12), dp(12));
        row.setBackground(roundedDrawable(selected ? "#111111" : "#F5F6F8", 18, selected ? null : "#E7E9EE", 1));
        row.setOnClickListener(v -> selectProfile(profile));

        LinearLayout textWrap = new LinearLayout(this);
        textWrap.setOrientation(LinearLayout.VERTICAL);

        TextView name = new TextView(this);
        name.setText(profile.name);
        name.setTextSize(TypedValue.COMPLEX_UNIT_SP, 15);
        name.setTypeface(Typeface.DEFAULT_BOLD);
        name.setTextColor(selected ? Color.WHITE : Color.parseColor("#111111"));
        textWrap.addView(name, lpMatchWrapNoMargin());

        TextView meta = new TextView(this);
        meta.setText(profile.carrier + " / " + profile.transport);
        meta.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12);
        meta.setTextColor(selected ? Color.parseColor("#D7DBE2") : Color.parseColor("#6F737B"));
        meta.setPadding(0, dp(5), 0, 0);
        textWrap.addView(meta, lpMatchWrapNoMargin());

        row.addView(textWrap, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f));

        TextView edit = smallRoundButton("i");
        edit.setTextColor(selected ? Color.parseColor("#111111") : Color.WHITE);
        edit.setBackground(roundedDrawable(selected ? "#FFFFFF" : "#111111", 18, null, 0));
        edit.setOnClickListener(v -> openEditProfileEditor(profile));
        LinearLayout.LayoutParams editLp = squareLp(dp(36));
        editLp.setMargins(dp(10), 0, 0, 0);
        row.addView(edit, editLp);

        return row;
    }

    private List<Profile> loadProfiles() {
        SharedPreferences prefs = getSharedPreferences(PREFS, MODE_PRIVATE);
        List<Profile> out = new ArrayList<>();
        for (String id : getProfileIds()) {
            String link = prefs.getString("profile_" + id + "_link", "");
            if (link == null || link.trim().isEmpty()) continue;
            String name = prefs.getString("profile_" + id + "_name", "olcRTC profile");
            String carrier = prefs.getString("profile_" + id + "_carrier", "unknown");
            String transport = prefs.getString("profile_" + id + "_transport", "unknown");
            out.add(new Profile(id, name, link, carrier, transport));
        }
        return out;
    }

    private Profile getSelectedProfile() {
        if (selectedProfileId == null || selectedProfileId.trim().isEmpty()) return null;
        for (Profile p : loadProfiles()) {
            if (p.id.equals(selectedProfileId)) return p;
        }
        return null;
    }

    private String findProfileIdByLink(String link) {
        SharedPreferences prefs = getSharedPreferences(PREFS, MODE_PRIVATE);
        for (String id : getProfileIds()) {
            String stored = prefs.getString("profile_" + id + "_link", "");
            if (link.equals(stored)) return id;
        }
        return null;
    }

    private List<String> getProfileIds() {
        SharedPreferences prefs = getSharedPreferences(PREFS, MODE_PRIVATE);
        String raw = prefs.getString(KEY_PROFILE_IDS, "");
        List<String> ids = new ArrayList<>();
        if (raw == null || raw.trim().isEmpty()) return ids;
        for (String part : raw.split(",")) {
            String id = part.trim();
            if (!id.isEmpty() && !ids.contains(id)) ids.add(id);
        }
        return ids;
    }

    private void addProfileId(String id) {
        List<String> ids = getProfileIds();
        if (!ids.contains(id)) ids.add(id);
        saveProfileIds(ids);
    }

    private void removeProfileId(String id) {
        List<String> ids = getProfileIds();
        ids.remove(id);
        saveProfileIds(ids);
    }

    private void saveProfileIds(List<String> ids) {
        StringBuilder sb = new StringBuilder();
        for (String id : ids) {
            if (sb.length() > 0) sb.append(",");
            sb.append(id);
        }
        getSharedPreferences(PREFS, MODE_PRIVATE).edit().putString(KEY_PROFILE_IDS, sb.toString()).apply();
    }

    private String buildProfileName(OlcConfig config) {
        if (config.comment != null && !config.comment.trim().isEmpty() && !"direct".equalsIgnoreCase(config.comment.trim())) {
            return config.comment.trim();
        }
        String client = config.clientId == null ? "" : config.clientId.trim();
        if (!client.isEmpty() && !"default".equalsIgnoreCase(client)) {
            return config.carrier + " | " + config.transport + " | " + client;
        }
        return config.carrier + " | " + config.transport;
    }

    private String shortLink(String link) {
        if (link == null) return "";
        if (link.length() <= 120) return link;
        return link.substring(0, 52) + "..." + link.substring(link.length() - 36);
    }

    private void hideEditorFocus() {
        if (linkInput != null) {
            linkInput.clearFocus();
            linkInput.setCursorVisible(false);
        }
        if (profileNameInput != null) {
            profileNameInput.clearFocus();
            profileNameInput.setCursorVisible(false);
        }
        try {
            InputMethodManager imm = (InputMethodManager) getSystemService(INPUT_METHOD_SERVICE);
            View v = getCurrentFocus();
            if (imm != null && v != null) imm.hideSoftInputFromWindow(v.getWindowToken(), 0);
        } catch (Throwable ignored) {}
    }

    private void setStatus(String text) {
        if (statusView != null) statusView.setText(text);
    }

    private void setDetails(String text) {
        if (detailsView != null) detailsView.setText(text);
    }

    private void applyServiceStatus(String rawStatus) {
        setStatus(compactStatus(rawStatus));
        setDetails(shortDetails(rawStatus));
        updateStateFromStatus(rawStatus);
    }

    private String compactStatus(String raw) {
        String s = raw == null ? "" : raw.trim();
        String lower = s.toLowerCase();

        if (lower.contains("vpn connected")) return "VPN подключён. Трафик идёт через туннель.";
        if (lower.contains("отключено")) return "VPN отключён.";
        if (lower.contains("ссылка разобрана")) return "Ссылка принята. Готовлю подключение.";
        if (lower.contains("dns auto")) return "DNS выбран автоматически.";
        if (lower.contains("подключаю olcrtc")) return "Подключаю olcRTC...";
        if (lower.contains("локальный socks")) return "olcRTC подключён. Проверяю локальный SOCKS.";
        if (lower.contains("olcrtc подключён")) return "olcRTC подключён. Поднимаю VPN.";
        if (lower.contains("автопереподключение")) return firstLine(s);
        if (lower.contains("сеть изменилась")) return "Сеть изменилась. Пересоздаю туннель.";
        if (lower.contains("переподключаюсь")) return firstLine(s);
        if (lower.contains("keepalive fail")) return "Туннель отвечает нестабильно. Проверяю соединение.";
        if (lower.contains("отключаюсь")) return "Отключаюсь...";
        if (lower.contains("ошибка")) return humanError(s);
        if (lower.contains("failed") || lower.contains("exception")) return humanError(s);
        return firstLine(s);
    }

    private String shortDetails(String raw) {
        if (raw == null || raw.trim().isEmpty()) return "Нет деталей.";
        String s = raw.trim();
        s = s.replaceAll("(?i)(key=)[0-9a-f]{16,}", "$1hidden");
        s = s.replaceAll("(?i)(#)[0-9a-f]{16,}", "$1hidden");
        if (s.length() > 900) s = s.substring(0, 900) + "\n...";
        return s;
    }

    private String humanError(String raw) {
        String s = raw == null ? "" : raw.toLowerCase();

        if (s.contains("videochannel") && s.contains("ffmpeg")) return "videochannel требует нативный core с ffmpeg. В этой Android-сборке используй vp8channel или seichannel.";
        if ((s.contains("seichannel") || s.contains("videochannel")) && (s.contains("setseioptions") || s.contains("setvideooptions") || s.contains("startwithtransport") || s.contains("combo aar"))) return "Нужен свежий combo AAR с поддержкой universal-carrier. Собери scripts/build_combo_aar.sh и пересобери APK.";
        if (s.contains("only datachannel") || s.contains("use datachannel")) return "Эта ссылка не поддерживается этой сборкой. Используй datachannel или vp8channel.";
        if (s.contains("vp8channel") && (s.contains("no startwithtransport") || s.contains("settransport") || s.contains("rebuild app/libs/olcrtccombo.aar"))) return "Нужен свежий combo AAR с поддержкой vp8channel. Собери scripts/build_combo_aar.sh и пересобери APK.";
        if (s.contains("bad_link") || s.contains("empty olcrtc link")) return "Вставь корректную olcRTC-ссылку.";
        if (s.contains("combined mobile aar") || s.contains("combo aar")) return "Core не найден. Собери combo AAR и пересобери APK.";
        if (s.contains("vpn permission") || s.contains("tun establish") || s.contains("permission not granted")) return "Android не разрешил создать VPN-подключение.";
        if (s.contains("stream.wb.ru") && (s.contains("lookup") || s.contains("dns"))) return "DNS не смог найти stream.wb.ru. Проверь сеть или попробуй переподключиться.";
        if (s.contains("ice failed") || s.contains("olcrtc core stopped")) return "Канал olcRTC оборвался. Приложение попробует переподключиться.";
        if (s.contains("keepalive failed") || s.contains("keepalive fail")) return "Туннель перестал отвечать. Переподключаюсь.";
        if (s.contains("remote not ready") || s.contains("host unreachable") || s.contains("timeout")) return "Удалённая сторона не ответила. Попробую переподключиться.";
        if (s.contains("connection refused")) return "Соединение отклонено. Проверь ссылку и сервер.";
        return "Ошибка подключения. Детали ниже.";
    }

    private String firstLine(String s) {
        if (s == null || s.trim().isEmpty()) return "";
        String line = s.trim().split("\\r?\\n", 2)[0].trim();
        return line.length() > 120 ? line.substring(0, 120) + "..." : line;
    }

    private String safe(String s) {
        return s == null ? "" : s;
    }

    private void updateStateFromStatus(String status) {
        String s = status == null ? "" : status.toLowerCase();
        if (s.contains("vpn connected")) {
            applyConnectionState(STATE_CONNECTED, "Подключено");
        } else if (s.contains("olcrtc подключён") || s.contains("подключаю olcrtc") || s.contains("автопереподключение") || s.contains("запускаю") || s.contains("ссылка разобрана") || s.contains("сеть изменилась") || s.contains("keepalive")) {
            applyConnectionState(STATE_CONNECTING, "Подключение...");
        } else if (s.contains("ошибка") || s.contains("не выдано") || s.contains("отключаюсь") || s.contains("отключено") || s.contains("отключение отправлено") || s.contains("stopped")) {
            applyConnectionState(STATE_DISCONNECTED, "Отключено");
        }
    }

    private void applyConnectionState(int state, String subtitle) {
        connectionState = state;
        if (heroSubtitle != null && !TextUtils.isEmpty(subtitle)) heroSubtitle.setText(subtitle);

        if (stateChip != null) {
            if (state == STATE_CONNECTED) {
                stateChip.setText("Connected");
                stateChip.setTextColor(Color.parseColor("#0A0A0A"));
                stateChip.setBackground(roundedDrawable("#D7F8DD", 16, null, 0));
            } else if (state == STATE_CONNECTING) {
                stateChip.setText("Connecting");
                stateChip.setTextColor(Color.parseColor("#0A0A0A"));
                stateChip.setBackground(roundedDrawable("#E8ECF6", 16, null, 0));
            } else {
                stateChip.setText("Disconnected");
                stateChip.setTextColor(Color.parseColor("#5B616B"));
                stateChip.setBackground(roundedDrawable("#F0F2F5", 16, null, 0));
            }
        }

        if (toggleButton != null) {
            if (state == STATE_CONNECTED) {
                toggleButton.setText("Отключить");
            } else if (state == STATE_CONNECTING) {
                toggleButton.setText("Остановить");
            } else {
                toggleButton.setText("Подключить");
            }
        }
    }

    private boolean isIgnoringBatteryOptimizations() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true;
        try {
            PowerManager pm = (PowerManager) getSystemService(POWER_SERVICE);
            return pm != null && pm.isIgnoringBatteryOptimizations(getPackageName());
        } catch (Throwable ignored) {
            return false;
        }
    }

    private void requestBatteryOptimizationExemption() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            setStatus("На этой версии Android отдельное разрешение фона не нужно.");
            return;
        }
        if (isIgnoringBatteryOptimizations()) {
            setStatus("Фоновая работа уже разрешена.");
            return;
        }
        try {
            Intent intent = new Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS);
            intent.setData(Uri.parse("package:" + getPackageName()));
            startActivity(intent);
            setStatus("Подтверди отключение энергосбережения для стабильного VPN.");
        } catch (Throwable t) {
            try {
                Intent intent = new Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS);
                startActivity(intent);
                setStatus("Открой olcRTC VPN и отключи оптимизацию батареи вручную.");
            } catch (Throwable ignored) {
                setStatus("Не удалось открыть настройки батареи.");
            }
        }
    }

    private TextView sectionLabel(String text) {
        TextView view = new TextView(this);
        view.setText(text);
        view.setTextColor(Color.parseColor("#6F737B"));
        view.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12);
        view.setTypeface(Typeface.DEFAULT_BOLD);
        return view;
    }

    private TextView primaryButton(String text) {
        TextView b = new TextView(this);
        b.setText(text);
        b.setTextColor(Color.WHITE);
        b.setTextSize(TypedValue.COMPLEX_UNIT_SP, 16);
        b.setTypeface(Typeface.DEFAULT_BOLD);
        b.setGravity(Gravity.CENTER);
        b.setPadding(dp(16), dp(18), dp(16), dp(18));
        b.setBackground(roundedDrawable("#111111", 22, null, 0));
        b.setClickable(true);
        return b;
    }

    private TextView secondaryTextButton(String text) {
        TextView b = new TextView(this);
        b.setText(text);
        b.setTextColor(Color.parseColor("#111111"));
        b.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14);
        b.setGravity(Gravity.CENTER);
        b.setPadding(dp(14), dp(15), dp(14), dp(15));
        b.setBackground(roundedDrawable("#F0F2F5", 18, "#E7E9EE", 1));
        b.setClickable(true);
        return b;
    }

    private TextView actionButton(String text) {
        TextView b = secondaryTextButton(text);
        b.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14);
        return b;
    }

    private TextView smallRoundButton(String text) {
        TextView b = new TextView(this);
        b.setText(text);
        b.setTextColor(Color.WHITE);
        b.setTextSize(TypedValue.COMPLEX_UNIT_SP, 20);
        b.setTypeface(Typeface.DEFAULT_BOLD);
        b.setGravity(Gravity.CENTER);
        b.setBackground(roundedDrawable("#111111", 18, null, 0));
        b.setClickable(true);
        return b;
    }

    private LinearLayout cardLayout() {
        LinearLayout layout = new LinearLayout(this);
        layout.setOrientation(LinearLayout.VERTICAL);
        layout.setBackground(roundedDrawable("#FFFFFF", 24, "#E9EBEF", 1));
        return layout;
    }

    private GradientDrawable roundedDrawable(String fillColor, int radiusDp, String strokeColor, int strokeDp) {
        GradientDrawable drawable = new GradientDrawable();
        drawable.setColor(Color.parseColor(fillColor));
        drawable.setCornerRadius(dp(radiusDp));
        if (strokeColor != null && strokeDp > 0) drawable.setStroke(dp(strokeDp), Color.parseColor(strokeColor));
        return drawable;
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }

    private LinearLayout.LayoutParams lpMatchWrap() {
        LinearLayout.LayoutParams lp = lpMatchWrapNoMargin();
        lp.setMargins(0, dp(8), 0, dp(8));
        return lp;
    }

    private LinearLayout.LayoutParams lpMatchWrapNoMargin() {
        return new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
    }

    private LinearLayout.LayoutParams lpWrapWrapNoMargin() {
        return new LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
    }

    private LinearLayout.LayoutParams rowTextButtonLp(float weight) {
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, weight);
        lp.setMargins(dp(3), 0, dp(3), 0);
        return lp;
    }

    private LinearLayout.LayoutParams squareLp(int size) {
        return new LinearLayout.LayoutParams(size, size);
    }
}
