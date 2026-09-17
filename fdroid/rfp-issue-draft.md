# RFP issue draft for gitlab.com/fdroid/rfp

Paste this into a new issue at https://gitlab.com/fdroid/rfp/-/issues/new.
Everything below "---" is the issue body; the line right below this one is
the GitLab issue **Title** field, not part of the body.

Title: Pterodactyl Mobile (Lil-Ptero)

---

* [x] The app complies with the inclusion criteria (https://f-droid.org/wiki/page/Inclusion_Policy)
* [x] The app is not already listed in the repo or issue tracker.
* [x] The original app author has been notified (and does not oppose the inclusion). — I am the original author.
* [ ] Donated to support the maintenance of this app in F-Droid.

---------------------

### Link to the source code:
https://github.com/SusieeTheLinuxUser/Lil-Ptero

### Link to app in another app store:
None yet — distributed via GitHub Releases: https://github.com/SusieeTheLinuxUser/Lil-Ptero/releases

### License used:
MIT

### Category:
Internet

### Summary:
View and control your Minecraft servers on any Pterodactyl panel, from Android.

### Description:
Pterodactyl Mobile is a free, open-source Android client for the Pterodactyl game server panel. It works with any Pterodactyl host — you connect with your own panel URL and a personal Client API key, and the app talks directly to your panel's API with no backend in between.

Features: server list with live resource usage (CPU, memory, disk), power controls (start/restart/stop/kill), and a live console with command input over the panel's websocket.

Built with Flutter, minimal dependencies (just `http` and `flutter_secure_storage` for Keystore-backed credential storage), no analytics, no ads, no trackers.
