# otobo-rocketchat

Extension for OTOBO that allows to open a RocketChat channel for a given Ticket and adding all the involved participants.

## Extension Architecture

* `Kernel::Output::HTML::TicketMenu::RocketChat` Module that displays a menu entry for the Open/Close RocketChat Channel action
* `Kernel::Modules::AgentTicketRocketChat` Module that opens and closes RocketChat Channels
* `Kernel::Modules::AdminRocketChat` Module that allows to configure the Extension and its Webservice
* `Kernel::GenericInterface::Invoker::RocketChat` Invoker Modules for constructing the requests for the Rocket.Chat API
  * `Kernel::GenericInterface::Invoker::RocketChat::Lookup`
  * `Kernel::GenericInterface::Invoker::RocketChat::GroupCreate`
  * `Kernel::GenericInterface::Invoker::RocketChat::GroupAddOwner`
  * `Kernel::GenericInterface::Invoker::RocketChat::GroupMemberOf`
  * `Kernel::GenericInterface::Invoker::RocketChat::GroupSetAnnouncement`
  * `Kernel::GenericInterface::Invoker::RocketChat::RoomExists`
  * `Kernel::GenericInterface::Invoker::RocketChat::UserInfo`
  * `Kernel::GenericInterface::Invoker::RocketChat::Login`
  * `Kernel::GenericInterface::Invoker::RocketChat::Logout`
* `Kernel::System::RocketChat`: Exposes an API for Interacting with Rocket.Chat to other Modules of this extension as well as some other common operations. Most notably wraps all Invokers for convenient usage and takes care of object allocation.
* `Kernel::System::RocketChat::Util`: Helper functions and constants that need to be imported even if the extension is not active or properly configured
* Config
  * `Kernel/Config/Files/XML/RocketChat.xml`: Contains "static" configuration like Module registrations.
  * `Kernel/Config/Files/XML/RocketChatUserConfig.xml`: Contains Configuration modifying the behavior of the RocketChat extension. All settings here are exposed under the `Core::RocketChat` navigation point in the system configuration, but are intended to be altered via the interface provided by `Kernel::Modules::AdminRocketChat`.

The RocketChat Invokers are called using a `Kernel::GenericInterface::Requester`
using `Kernel::GenericInterface::Transport::HTTP::REST` transport with a webservice
specially set up using `Kernel::Modules::AdminRocketChat`. This further relies on
the OTOBO extension `requester-headers` which is also part of this repository.

## Documentation

Some perl packages/objects are documented using `pod`. You can build html documentation using using the following command if you have `pod2html` installed:

```bash
make
$BROWSER docs/index.html  # open overview page
```

## Minimal Permissions for Rocket.Chat User

The Rocket.Chat User used by the extension must have the following permissions
in its role. It is wise to create a role specifically for it with only these
minimal permissions to limit the impact a possible exploit of the extension
could have.

The required permissions depend partly on your settings.

### Permissions for Email User Discovery

* Add User to Any Joined Channel
* Bypass Rate Limit for API
* Create Private Channels
* Edit Room
* Set Owner
* View Public Channel
* View Direct Messages
* View Full Other Users Info
* View Joined Room
* View User Administration

### Permissions for Username Discovery

For matching by username, the standard `user` role of Rocket.Chat is enough.

More specifically we only need the following permission: Create Private Channels.
Additionally “Bypass Rate Limit for API” might be useful as well.

## Changelog

### 0.1.0

* Port from OTRS 6 to OTOBO 10.0
* Rename to `otobo-rocketchat`

**Breaking Change**: No longer works with OTRS.

### 0.0.4

Refactor URL construction to use `CGI` package from CPAN.

Last release compatible with OTRS 6.

### 0.0.3

This release contains a bug fix related with `Kernel::Output::HTML::TicketMenu::RocketChat`.
In hiding the entry if the user doesn't have permission to use it the module was a little
overzealous: It would generally hide the entry if the respective user wasn't ticket owner.
However it was intended of course that other agents and customers would be able to use the
link to a created Rocket.Chat channel.

Now the proper behavior has been implemented:

* If a corresponding channel exists, we always show the entry.
* If no corresponding channel exisits, we hide the entry from everyone but the ticket owner.
* If the dynamic ticket menu has been disable, we always show the entry regardless of access.

### 0.0.2

* Use `/groups.list` instead of `/rooms.adminRooms` for checking if an OTRS
  channel in Rocket.Chat already exists via `Kernel::System::RocketChat::GroupMemberOf()`.
  * The main motivation is that checking if the OTRS Rocket.Chat account is
    in a group requires less permissions than the account searching through
    all (private) channels of others on the Rocket.Chat instance.
  * This relies on the fact that the OTRS Rocket.Chat account is member of all
    OTRS ticket channels if they were created by the extension.
  * A slight edge case is introduced: If there is a existing room with a
    matching name created by someone else, the extension will assume it does
    not exist at all and try to create it anyways. This will result in an
    error which is arguably better than redirecting to a channel which
    is not in fact a OTRS ticket channel (which was the previous behavior).
    Such cases should be rare anyways with a well-chosen channel prefix.
* Add new method to find Rocket.Chat users for OTRS users: Username matching.
  * This is the simplest imaginable method: We just assume that for every
    OTRS user there is a Rocket.Chat user with the same username.
  * We check if these users actually exists and determine their Rocket.Chat
    user ID using `Kernel::System::RocketChat::UserInfo()`.
  * The main advantage over email discovery is that we don't need to access
    `/users.list` with admin privileges in order to search through emails
    which aren't visible to normal users. With username discovery enabled
    a normal Rocket.Chat user account could be used for the extension
    further minimizing the possible attack impact an exploit of the extension
    or OTRS would have on the connected Rocket.Chat instance.
* Optionally make it possible to add users to the created channel via
  `/groups.invite` instead of directly in `/groups.create`.
  * This offers a slightly better user experience: Rocket.Chat users are
    notified as soon as they are added while with `/groups.create` they
    are just silently added to the channel.
  * However `/groups.invite` increases the number of API calls required and
    might be problematic for load time and/or rate limit.
* Document minimum required Rocket.Chat permissions in `otobo-rocketchat/README.md`:
  As part of the effort to minimize the required permissions for the extension,
  also the minimum required permissions were listed, as for email discovery
  the required permissions are less than an admin account and even for the
  username discovery it's less than a normal user.
* `AgentTicketRocketChat`: Translate group announcement when creating a channel
* `AdminRocketChat`:
  * Minor cosmetic fixes
  * Reword and restructure some parts of the default action.
  * Allow to change new settings `UserDiscoveryType` and `InviteUsers`.
* Minor fixes in technical documentation
* Remove some `success` response field checks in Invokers. It seems that the
  OTRS JSON parsing is really unreliable after all. We don't desperately need
  to check the success field after all since a failure is generally not (never?)
  accompanied with a HTTP status of 200.
* `RocketChat::GroupCreate` Invoker: allow creation of empty groups
* Bugfix in `GroupAddOwner`: fail if email lookup returns nothing

### 0.0.1

Initial pre-release version for testing purposes.

* `AgentRocketChat`
  * Access corresponding Rocket.Chat channels from OTRS `AgentTicketZoom`
  * Open Rocket.Chat channel for ticket from OTRS `AgentTicketZoom`
  * Initialize channel with ticket owner as channel owner and return link as well as ticket title in announcement
* Configure extension behavior and Web Service connection details using `AdminRocketChat`
* Module specific interaction with OTRS and Rocket.Chat's API via `Kernel::System::RocketChat`
* Preliminary german translation
* Depends on `requester-headers` for an extension to `GenericInterface`'s `Requester`

## Todo

* [x] Check if Channel already exists, redirect if so
* [x] Create Group
* [x] Split certain common tasks into shared RocketChat Object (?)
* [x] Rework collection of Involved Emails
  * [x] Check Articles for Emails
  * [x] Respect config for Cc-Emails and Emails of hidden entries
  * [x] Allow to disable collection from Articles?
  * [x] Option to make TicketMenu non dynamic to improve AgentTicketZoom performance
* [ ] Improve error messages in certain cases
* [ ] Test customer experience
* [x] Make someone Group Owner
  * [x] Prevent Groups without an Owner, i. e. refuse to create channels, if owner has no Rocket.Chat account
* [x] Send informative message to group / Set topic/title (?)
  * [x] Add Ticket title
* [x] Convenient Config for RocketChat Extension
  * [x] Setup Webservice
  * [x] Delete Webservice
  * [x] Configure Module behavior
  * [x] Use Webservice from Config in `Kernel::System::RocketChat`
  * [x] Allow Extension to be deactivated without de-registering any modules
* [x] Security / Access Control
  * [x] Basic Access Control
  * [ ] ACL support
  * [ ] Add different levels (Everyone, only agents, ...) and make them configurable
* [x] OTOBO Code policy
* [x] Fix JSON Boolean handling
* [ ] Translations to german
  * [x] User Frontend Translation
  * [ ] Error Messages Translation
  * [ ] System Configuration Translation
* [x] OTOBO Extension Package
* [x] Use `groups.list` for channel look up (less rights required)
* [x] ~~`users.list` with minimal rights?~~ Matching by user name
* [ ] After Archiving, add chat log to ticket (probably using OTOBO chat bot, consider privacy aspects, include logging in welcome message)

### Optional

* [ ] Consider reimplementing `RocketChat::Login` client side in JS for *Datensparsamkeit*
* [ ] Keep track of channels (and if they are created by OTOBO) in DB (would prevent channel clashes with already existing Rocket.Chat channels)
* [ ] Closing/Archiving of Channel (probably would need additional menu entry, can be done via Rocket.Chat GUI, low priority)
* [ ] Add functionality to add new email addresses to the channel (probably not really necessary)
