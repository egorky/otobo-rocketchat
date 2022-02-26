# --
# Copyright © 2020 Lukas Epple, Universität Augsburg
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --
package Kernel::Language::de_RocketChat;

use strict;
use warnings;
use utf8;

use vars qw(@ISA $VERSION);

sub Data {
    my $Self = shift;

    # $$START$$

    # Admin Screen and System Configuration
    $Self->{Translation}->{'Configure the Rocket.Chat Extension.'} = 'Die Rocket.Chat-Erweiterung konfigurieren.';

    # AdminRocketChat UI
    $Self->{Translation}->{'Configure Rocket.Chat Extension'} = 'Rocket.Chat-Erweiterung konfigurieren';
    $Self->{Translation}->{'Setup Rocket.Chat Webservice'} = 'Web-Service für Rocket.Chat konfigurieren';
    $Self->{Translation}->{'Delete Rocket.Chat Webservice'} = 'Rocket.Chat-Web-Service löschen';

    $Self->{Translation}->{'Don\'t use the Webservice Management to change the Webservice created here, since it might break the Rocket.Chat extension. If you need to change something, delete and re-create the Webservice here instead.'} = 'Benutzen Sie nicht die Web-Service-Verwaltung, um den Web-Service der Rocket.Chat-Erweiterung zu ändern, sondern löschen und erstellen Sie diesen besser neu.';

    ## DeleteWebservice
    $Self->{Translation}->{'Can\'t delete any Rocket.Chat Webservice since none exists.'} = 'Es ist nicht möglich, den Rocket.Chat-Web-Service zu löschen, da keiner existiert.';
    $Self->{Translation}->{'If you delete the Rocket.Chat webservice, users will lose the ability to create or jump to Rocket.Chat Channels directly from OTOBO. No existing Rocket.Chat channels will be deleted and all settings except connection details and credentials will persist.'} = 'Wenn der Rocket.Chat-Web-Service gelöscht wird, können Benutzer von OTOBO keine Rocket.Chat-Kanäle erstellen oder von OTOBO aus abrufen. Es werden aber keine existierenden Channels oder Einstellungen außer Zugangsdaten gelöscht.';

    ## Change
    $Self->{Translation}->{'The Rocket.Chat Webservice hasn\'t been set up. To begin, use the button on the left to configure OTOBO\'s connection to your Rocket.Chat instance.'} = 'Der Web-Service für Rocket.Chat wurde noch nicht konfiguriert. Benutzen Sie zunächst die Schaltfläche links, um dies zu tun.';
    $Self->{Translation}->{'Activation'} = 'Aktivierung';
    $Self->{Translation}->{'You can manually enable and disable the extension when it is installed. If you have enabled the extension and it does not show here that it is fully configured, there is an error with its configuration and it consequently is not active. In such a situation try recreating the Webservice which is usually the cause of such a situation.'} = 'Sie können die Erweiterung manuell aktivieren und deaktivieren ohne sie zu deinstallieren. Die Erweiterung ist aber nur in Betrieb, wenn sie aktiviert und vollständig konfiguriert ist.';
    $Self->{Translation}->{'Extension Enabled'} = 'Erweiterung aktiviert';
    $Self->{Translation}->{'Extension Fully Configured'} = 'Erweiterung vollständig konfiguriert';
    $Self->{Translation}->{'Used Webservice'} = 'Verwendeter Web-Service';
    $Self->{Translation}->{'Channel Creation'} = 'Channel-Erstellung';
    $Self->{Translation}->{'Channel Prefix'} = 'Channel-Präfix';
    $Self->{Translation}->{'Channels created by this extension are named by concatenating a channel prefix configured here with the ticket ID of the corresponding OTOBO ticket, i. e. channel prefix "uni-augsburg-" and ticket ID 30017 would result in the channel name "uni-augsburg-30017".'} = 'Rocket.Chat-Channel, die von dieser Erweiterung erstellt werden, werden benannt, indem an den hier konfigurierten Channel-Präfix die Ticket-ID angehängt wird: Mit Präfix "uni-augsburg-" und Ticket-ID 30017 ergäbe sich z. B. "uni-augsburg-30017".';
    $Self->{Translation}->{'The Rocket.Chat extension can either add all involved users to the group in the creation process or invite them directly afterwards. Since invites currently don\'t have to be accepted in Rocket.Chat, this only makes a slight difference: The former takes less API calls, but the latter has a slightly better user experience since users will be notified that they have been added to a group.'} = 'Die Rocket.Chat-Erweiterung kann entweder alle involvierten Benutzer direkt bei der Erstellung des Channels hinzufügen oder die Benutzer direkt anschließend zum Channel einladen. Da Rocket.Chat-Einladungen nicht akzeptiert werden ist der Unterschied nur subtil: Im ersteren Fall benötigt man weniger API-Abrufe, im letzteren erhalten die Benutzer aber eine Benachrichtigungen, dass sie zu einem Channel hinzugefügt wurden.';
    $Self->{Translation}->{'User Addition Method'} = 'Hinzufügungsweise';
    $Self->{Translation}->{'Invite to channel'} = 'Zum Channel einladen';
    $Self->{Translation}->{'Add directly to channel'} = 'Direkt zum Channel hinzufügen';
    $Self->{Translation}->{'User Discovery'} = 'Benutzer-Suche';
    $Self->{Translation}->{'User Discovery Method'} = 'Suchmethode';
    $Self->{Translation}->{'The Rocket.Chat extension has two methods of finding matching Rocket.Chat users for OTOBO users: Either the OTOBO usernames or the email addresses stored in OTOBO can be used to search for matching Rocket.Chat users. The latter however requires additional privileges for the configured Rocket.Chat “bot” user.'} = 'Die Rocket.Chat-Erweiterung unterstützt zwei Methoden, um für OTOBO-Benutzer den entsprechenden Rocket.Chat-Benutzer zu finden: Dafür wird entweder die Email-Adresse des OTOBO-Benutzers oder sein Benutzername verwendet. Die erste Methode benötigt jedoch zusätzliche Privilegien beim konfigurierten OTOBO-Benutzer.';
    $Self->{Translation}->{'Email User Discovery Rules'} = 'Regeln für Email-Benutzer-Suche';
    $Self->{Translation}->{'Regardless of the user discovery method, the ticket owner, customer and all involved agents will be added to any created Rocket.Chat group. If email discovery is used, the extension can additionally check all messages belonging to the ticket for email addresses not previously discovered. You can enable and configure this behavior here.'} = 'Bei allen Suchmethoden werden der Kunde, der Besitzer des Tickets und alle involvierten Agenten hinzugefügt. Wenn Email-Suche verwendet wird, dann können zusätzlich noch alle mit dem Ticket assozierten Emails nach weiteren Benutzern durchsucht werden. Dies können Sie hier anschalten und konfigurieren.';
    $Self->{Translation}->{'Include Users from associated Email messages?'} = 'Benutzer aus Email-Nachrichten berücksichtigen?';
    $Self->{Translation}->{'Search the Cc header of Emails?'} = 'In Cc gesetzte Benutzer berücksichtigen?';
    $Self->{Translation}->{'Search Emails hidden to the Customer?'} = 'Benutzer aus vor dem Kunden versteckten Nachrichten berücksichtigen?';
    $Self->{Translation}->{'Ticket Menu Entry'} = 'Ticket-Menüeintrag';
    $Self->{Translation}->{'When a ticket is viewed in OTOBO, by default the Rocket.Chat extension will check if a corresponding channel exists and adjust the text of the menu item accordingly. While this is convenient, it has a performance cost since the Rocket.Chat API must be queried for this. If this impact is too severe (e. g. if your Rocket.Chat instance is unreliable or slow), you can disable this here and use a static menu entry instead.'} = 'Wenn ein Ticket in OTOBO aufgerufen wird, überprüft die Rocket.Chat-Erweiterung, ob der korrespondierende Rocket.Chat-Channel schon existiert, und passt den Text des Menüeintrags entsprechend an. Dazu wird allerdings ein HTTP-Request an die Rocket.Chat-API gesendet, was den Seitenaufruf verlangsamen kann. Falls diese Einbuße zu groß ist, können Sie dies hier ausschalten und stattdessen einen statischen Text verwenden.';
    $Self->{Translation}->{'Enable Dynamic Ticket Menu Entry?'} = 'Dynamischen Menüeintrag verwenden?';
    $Self->{Translation}->{'Permissions'} = 'Berechtigungen';
    $Self->{Translation}->{'Only the ticket owner can open a Rocket.Chat channel and will be made channel owner as well. A link to an already created channel is shown to anyone able to access the ticket, the channel however can only be viewed by users automatically or manually added to it as it is created as a private group.'} = 'Nur der Besitzer des Tickets kann einen Rocket.Chat-Channel eröffnen und wird auch zum Verwalter des Channels gemacht. Alle, die auch das Ticket abrufen können, können auch den Link zum Channel sehen, den Channel selbst aber nur diejenigen, die automatisch oder manuell hinzugefügt wurden, da er als privater Channel erstellt wird.';

    ## SetupWebservice
    $Self->{Translation}->{'Rocket.Chat Webservice already exists! Delete it to setup a new one.'} = 'Es existiert bereits ein Rocket.Chat-Web-Service. Löschen Sie ihn, um einen neuen zu erstellen.';
    $Self->{Translation}->{'The API URL is typically the base URL of your Rocket.Chat instance plus "/api/v1/", e. g. "https://open.rocket.chat/api/v1/".'} = 'Die API-URL ist in der Regel die URL zur Instanz mit "/api/v1/" angehängt, wie z. B. "https://open.rocket.chat/api/v1/".';
    $Self->{Translation}->{'Base URL'} = 'URL der Instanz';
    $Self->{Translation}->{'API URL'} = 'API URL';
    $Self->{Translation}->{'Rocket.Chat Credentials'} = 'Zugangsdaten für Rocket.Chat';
    $Self->{Translation}->{'We need the credentials of an admin account to be used by the Rocket.Chat OTOBO extension. It will be part of all chat groups created by it, so it makes sense to create an OTOBO-specific bot account for this purpose. The credentials won\'t be stored permanently, instead they are used to obtain an “Authentication Token” which is then stored.'} = 'Für die Rocket.Chat-Erweiterung werden die Zugangsdaten eines Rocket.Chat-Administrator-Accounts benötigt, der aus technischen Gründen auch Teil aller erstellten Kanäle sein wird. Es macht also Sinn zu diesem Zwecke einen dedizierten Account zu erstellen. Die Zugangsdaten werden nicht dauerhaft gespeichert, sondern nur einmalig benutzt, um ein sogenanntes „Authentication Token“ zu bekommen.';

    # TicketMenu
    $Self->{Translation}->{'Go to Rocket.Chat Channel'} = 'Rocket.Chat-Channel aufrufen';
    $Self->{Translation}->{'Go to Rocket.Chat Channel for this ticket'} = 'Rocket.Chat-Channel für dieses Ticket aufrufen';
    $Self->{Translation}->{'Open Rocket.Chat Channel'} = 'Rocket.Chat-Channel erstellen';
    $Self->{Translation}->{'Open Rocket.Chat Channel for this ticket'} = 'Rocket.Chat-Channel für dieses Ticket erstellen';
    $Self->{Translation}->{'Open/go to Rocket.Chat Channel'} = 'Rocket.Chat-Channel erstellen bzw. aufrufen';
    $Self->{Translation}->{'Open new or go to existing Rocket.Chat Channel for this ticket'} = 'Neuen Rocket.Chat-Channel für dieses Ticket erstellen oder existierenden aufrufen';

    # AgentTicketRocketChat
    $Self->{Translation}->{'Ticket Title: %s | '} = 'Ticket-Titel: %s | ';
    $Self->{Translation}->{'Link to Ticket: %s'} = 'Link zum Ticket: %s';

    # $$STOP$$
    return 1;
}

1;
