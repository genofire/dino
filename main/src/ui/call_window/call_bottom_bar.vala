using Dino.Entities;
using Gtk;
using Pango;

public class Dino.Ui.CallBottomBar : Gtk.Box {

    public signal void hang_up();

    public bool audio_enabled { get; set; }
    public bool video_enabled { get; set; }

    public static IconSize ICON_SIZE_MEDIADEVICE_BUTTON = Gtk.icon_size_register("im.dino.Dino.CALL_MEDIADEVICE_BUTTON", 10, 10);

    public string counterpart_display_name { get; set; }

    private Button audio_button = new Button() { height_request=45, width_request=45, halign=Align.START, valign=Align.START, visible=true };
    private Overlay audio_button_overlay = new Overlay() { visible=true };
    private Image audio_image = new Image() { visible=true };
    private MenuButton audio_settings_button = new MenuButton() { halign=Align.END, valign=Align.END };
    public AudioSettingsPopover? audio_settings_popover;

    private Button video_button = new Button() { height_request=45, width_request=45, halign=Align.START, valign=Align.START, visible=true };
    private Overlay video_button_overlay = new Overlay() { visible=true };
    private Image video_image = new Image() { visible=true };
    private MenuButton video_settings_button = new MenuButton() { halign=Align.END, valign=Align.END };
    public VideoSettingsPopover? video_settings_popover;

    private MenuButton encryption_button = new MenuButton() { relief=ReliefStyle.NONE, height_request=30, width_request=30, margin_start=20, margin_bottom=25, halign=Align.START, valign=Align.END };
    private Image encryption_image = new Image.from_icon_name("changes-allow-symbolic", IconSize.BUTTON) { visible=true };

    private Label label = new Label("") { margin=20, halign=Align.CENTER, valign=Align.CENTER, wrap=true, wrap_mode=Pango.WrapMode.WORD_CHAR, hexpand=true, visible=true };
    private Stack stack = new Stack() { visible=true };

    public CallBottomBar() {
        Object(orientation:Orientation.HORIZONTAL, spacing:0);

        Overlay default_control = new Overlay() { visible=true };
        encryption_button.add(encryption_image);
        encryption_button.get_style_context().add_class("encryption-box");
        default_control.add_overlay(encryption_button);

        Box main_buttons = new Box(Orientation.HORIZONTAL, 20) { margin_start=40, margin_end=40, margin=20, halign=Align.CENTER, hexpand=true, visible=true };

        audio_button.add(audio_image);
        audio_button.get_style_context().add_class("call-button");
        audio_button.clicked.connect(() => { audio_enabled = !audio_enabled; });
        audio_button.margin_end = audio_button.margin_bottom = 5; // space for the small settings button
        audio_button_overlay.add(audio_button);
        audio_button_overlay.add_overlay(audio_settings_button);
        audio_settings_button.set_image(new Image.from_icon_name("go-up-symbolic", ICON_SIZE_MEDIADEVICE_BUTTON) { visible=true });
        audio_settings_button.get_style_context().add_class("call-mediadevice-settings-button");
        audio_settings_button.use_popover = true;
        main_buttons.add(audio_button_overlay);

        video_button.add(video_image);
        video_button.get_style_context().add_class("call-button");
        video_button.clicked.connect(() => { video_enabled = !video_enabled; });
        video_button.margin_end = video_button.margin_bottom = 5;
        video_button_overlay.add(video_button);
        video_button_overlay.add_overlay(video_settings_button);
        video_settings_button.set_image(new Image.from_icon_name("go-up-symbolic", ICON_SIZE_MEDIADEVICE_BUTTON) { visible=true });
        video_settings_button.get_style_context().add_class("call-mediadevice-settings-button");
        video_settings_button.use_popover = true;
        main_buttons.add(video_button_overlay);

        Button button_hang = new Button.from_icon_name("dino-phone-hangup-symbolic", IconSize.LARGE_TOOLBAR) { height_request=45, width_request=45, halign=Align.START, valign=Align.START, visible=true };
        button_hang.get_style_context().add_class("call-button");
        button_hang.get_style_context().add_class("destructive-action");
        button_hang.clicked.connect(() => hang_up());
        main_buttons.add(button_hang);

        default_control.add(main_buttons);

        label.get_style_context().add_class("text-no-controls");

        stack.add_named(default_control, "control-buttons");
        stack.add_named(label, "label");
        this.add(stack);

        this.notify["audio-enabled"].connect(on_audio_enabled_changed);
        this.notify["video-enabled"].connect(on_video_enabled_changed);

        audio_enabled = true;
        video_enabled = false;

        on_audio_enabled_changed();
        on_video_enabled_changed();

        this.get_style_context().add_class("call-bottom-bar");
    }

    public void set_encryption(Xmpp.Xep.Jingle.ContentEncryption? audio_encryption, Xmpp.Xep.Jingle.ContentEncryption? video_encryption, bool same) {
        encryption_button.visible = true;

        Popover popover = new Popover(encryption_button);
        if (audio_encryption == null) {
            encryption_image.set_from_icon_name("changes-allow-symbolic", IconSize.BUTTON);
            encryption_button.get_style_context().add_class("unencrypted");

            popover.add(new Label("This call isn't encrypted.") { margin=10, visible=true } );
            return;
        }

        encryption_image.set_from_icon_name("changes-prevent-symbolic", IconSize.BUTTON);
        encryption_button.get_style_context().remove_class("unencrypted");

        Box box = new Box(Orientation.VERTICAL, 5) { margin=10, visible=true };
        if (audio_encryption.encryption_name == "OMEMO") {
            box.add(new Label("<b>This call is encrypted with OMEMO.</b>") { use_markup=true, xalign=0, visible=true } );
        } else {
            box.add(new Label("<b>This call is end-to-end encrypted.</b>") { use_markup=true, xalign=0, visible=true });
        }

        if (same) {
            box.add(create_media_encryption_grid(audio_encryption));
        } else {
            box.add(new Label("<b>Audio</b>") { use_markup=true, xalign=0, visible=true });
            box.add(create_media_encryption_grid(audio_encryption));
            box.add(new Label("<b>Video</b>") { use_markup=true, xalign=0, visible=true });
            box.add(create_media_encryption_grid(video_encryption));
        }
        popover.add(box);

        encryption_button.set_popover(popover);
    }

    private Grid create_media_encryption_grid(Xmpp.Xep.Jingle.ContentEncryption? encryption) {
        Grid ret = new Grid() { row_spacing=3, column_spacing=5, visible=true };
        if (encryption.peer_key.length > 0) {
            ret.attach(new Label("Peer call key") { xalign=0, visible=true }, 1, 2, 1, 1);
            ret.attach(new Label("<span font_family='monospace'>" + format_fingerprint(encryption.peer_key) + "</span>") { use_markup=true, max_width_chars=25, ellipsize=EllipsizeMode.MIDDLE, xalign=0, hexpand=true, visible=true }, 2, 2, 1, 1);
        }
        if (encryption.our_key.length > 0) {
            ret.attach(new Label("Your call key") { xalign=0, visible=true }, 1, 3, 1, 1);
            ret.attach(new Label("<span font_family='monospace'>" + format_fingerprint(encryption.our_key) + "</span>") { use_markup=true, max_width_chars=25, ellipsize=EllipsizeMode.MIDDLE, xalign=0, hexpand=true, visible=true }, 2, 3, 1, 1);
        }
        return ret;
    }

    public AudioSettingsPopover? show_audio_device_choices(bool show) {
        audio_settings_button.visible = show;
        if (audio_settings_popover != null) audio_settings_popover.visible = false;
        if (!show) return null;

        audio_settings_popover = new AudioSettingsPopover();

        audio_settings_button.popover = audio_settings_popover;

        audio_settings_popover.set_relative_to(audio_settings_button);
        audio_settings_popover.microphone_selected.connect(() => { audio_settings_button.active = false; });
        audio_settings_popover.speaker_selected.connect(() => { audio_settings_button.active = false; });

        return audio_settings_popover;
    }

    public void show_audio_device_error() {
        audio_settings_button.set_image(new Image.from_icon_name("dialog-warning-symbolic", IconSize.BUTTON) { visible=true });
        Util.force_error_color(audio_settings_button);
    }

    public VideoSettingsPopover? show_video_device_choices(bool show) {
        video_settings_button.visible = show;
        if (video_settings_popover != null) video_settings_popover.visible = false;
        if (!show) return null;

        video_settings_popover = new VideoSettingsPopover();


        video_settings_button.popover = video_settings_popover;

        video_settings_popover.set_relative_to(video_settings_button);
        video_settings_popover.camera_selected.connect(() => { video_settings_button.active = false; });

        return video_settings_popover;
    }

    public void show_video_device_error() {
        video_settings_button.set_image(new Image.from_icon_name("dialog-warning-symbolic", IconSize.BUTTON) { visible=true });
        Util.force_error_color(video_settings_button);
    }

    public void on_audio_enabled_changed() {
        if (audio_enabled) {
            audio_image.set_from_icon_name("dino-microphone-symbolic", IconSize.LARGE_TOOLBAR);
            audio_button.get_style_context().add_class("white-button");
            audio_button.get_style_context().remove_class("transparent-white-button");
        } else {
            audio_image.set_from_icon_name("dino-microphone-off-symbolic", IconSize.LARGE_TOOLBAR);
            audio_button.get_style_context().remove_class("white-button");
            audio_button.get_style_context().add_class("transparent-white-button");
        }
    }

    public void on_video_enabled_changed() {
        if (video_enabled) {
            video_image.set_from_icon_name("dino-video-symbolic", IconSize.LARGE_TOOLBAR);
            video_button.get_style_context().add_class("white-button");
            video_button.get_style_context().remove_class("transparent-white-button");

        } else {
            video_image.set_from_icon_name("dino-video-off-symbolic", IconSize.LARGE_TOOLBAR);
            video_button.get_style_context().remove_class("white-button");
            video_button.get_style_context().add_class("transparent-white-button");
        }
    }

    public void show_counterpart_ended(string text) {
        stack.set_visible_child_name("label");
        label.label = text;
    }

    public bool is_menu_active() {
        return video_settings_button.active || audio_settings_button.active || encryption_button.active;
    }

    private string format_fingerprint(uint8[] fingerprint) {
        var sb = new StringBuilder();
        for (int i = 0; i < fingerprint.length; i++) {
            sb.append("%02x".printf(fingerprint[i]));
            if (i < fingerprint.length - 1) {
                sb.append(":");
            }
        }
        return sb.str;
    }
}