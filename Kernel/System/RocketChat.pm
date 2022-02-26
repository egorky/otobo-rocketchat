# --
# Copyright © 2020 Lukas Epple, Universität Augsburg
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::RocketChat;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsStringWithData IsInteger IsArrayRefWithData IsHashRefWithData);
use Kernel::System::EmailParser;

use Kernel::System::RocketChat::Util qw(:all);

our @ObjectDependencies = (
  'Kernel::System::GenericInterface::Webservice',
  'Kernel::GenericInterface::Requester',
  'Kernel::System::SysConfig',
  'Kernel::System::Log',
  'Kernel::System::CustomerUser',
  'Kernel::System::User',
  'Kernel::System::Ticket',
  'Kernel::System::Ticket::Article',
);

=encoding utf-8

=head1 NAME

C<Kernel::System::RocketChat> - Common module for Rocket.Chat extension

=head1 DESCRIPTION

Contains functions for interacting with the
L<Rocket.Chat REST API|https://docs.rocket.chat/developer-guides/rest-api/>
as well as common helper functions used a cross different modules of the
Rocket.Chat extension.

=head1 CONFIGURATION

The behavior of this module is influenced by the OTOBO system configuration.
L<Kernel::System::RocketChat::Util> exports the two settings' names which
are relevant for this: C<WEBSERVICE_CONFIG> and C<GENERAL_CONFIG>.

=over

=item *
C<WEBSERVICE_CONFIG> is a hash which contains a single key, C<WebserviceID>.
C<Kernel::System::RocketChat> will use the Webservice identified by this ID
for all its operations

=item *
C<GENERAL_CONFIG> controls the activation of this extension, for details on
that see L<IsExtensionActive()|Kernel::System::RocketChat::Util/IsExtensionActive()>.

It also defines the channel prefix used by this extension, see L<GetRoomName()|/GetRoomName>,
L<RoomExists()|/RoomExists> and L<GroupCreate()|/GroupCreate>.

Additionally it controls the behavior of L<GetInvolvedEmails()|/GetInvolvedEmails>, also refer
to that specific documentation for details.

=back

=head1 PUBLIC INTERFACE

=head2 General

=head3 new()

Create a RocketChat Object. Don't use directly, instead use the ObjectManager:

    my $RocketChat = $Kernel::OM->Get('Kernel::System::RocketChat');

Note that this might fail with C<die> if the extension is not configured
properly. To avoid such a situation use
L<Kernel::System::RocketChat::Util/IsExtensionActive()>
beforehand to check the configuration.

It will also exit with C<die>, if the configured Webservice does not exist.

=cut

sub new {
  my ($Type, %Param) = @_;

  my $Self = {};

  $Self->{SysConfigObject} = $Kernel::OM->Get('Kernel::System::SysConfig');

  my $IsActive = IsExtensionActive(
    SysConfigObject => $Self->{SysConfigObject},
  );

  # die if the module hasn't been activated or no webservice has been setup
  # TODO less extreme handling of this?
  die 'Extension not active, refusing to act on incomplete config' if(!$IsActive);

  my $WebserviceObject = $Kernel::OM->Get('Kernel::System::GenericInterface::Webservice');
  my %WebserviceConfig = $Self->{SysConfigObject}->SettingGet(
    Name => WEBSERVICE_CONFIG,
  );

  $Self->{Webservice} = $WebserviceObject->WebserviceGet(
    ID => $WebserviceConfig{EffectiveValue}->{WebserviceID},
  );

  # TODO rework this it is undesireable that AgentTicketZoom fails
  # just because of such a misconfiguration
  die 'Configured Webservice does not exist' if (!IsHashRefWithData($Self->{Webservice}));

  $Self->{Requester} = $Kernel::OM->Get('Kernel::GenericInterface::Requester');

  $Self->{TicketObject} = $Kernel::OM->Get('Kernel::System::Ticket');

  $Self->{Log} = $Kernel::OM->Get('Kernel::System::Log');

  $Self->{EmailParser} = Kernel::System::EmailParser->new(
    Mode  => 'Standalone',
    Debug => 0,
  );

  bless($Self, $Type);
  return $Self;
}

=head2 API Interaction

Interaction with the REST API of Rocket.Chat. Note that these functions don't
correspond to direct API endpoints all the time, since some do additional
data processing, as they are intended as special purpose calls not a general
PERL Rocket.Chat API mapping.

=head3 RoomExists()

Checks if a room of any type (channel, group) exists with a given name. For
this purpose it uses L<rooms.adminRooms|https://docs.rocket.chat/api/rest-api/methods/rooms/adminrooms>
to also be able to check if a private group of that name exists. Therefore
the Rocket.Chat API user must be admin.

    my $ExistsResult = $RC->RoomExists(
      RoomName => $RoomName,
    );

Returns:

   $ExistsResult = {
       Success => 1,
       Data => {
           Exists => 1,
           Type => 'p', # only if Exists = 1
       },
  };

The C<Type> field only is present, if the Room exists, it is either C<p> for
private group or C<c> for public channel.

=cut

sub RoomExists {
  my ($Self, %Param) = @_;
  my $RoomName;

  if(IsStringWithData($Param{RoomName})) {
    $RoomName = $Param{RoomName};
  } elsif(IsInteger($Param{TicketID})) {
    $RoomName = $Self->GetRoomName($Param{TicketID});
  } else {
    return {
      Success => 0,
      ErrorMessage => 'Need either TicketID or RoomName parameter',
    };
  }

  return $Self->{Requester}->Run(
    WebserviceID => $Self->{Webservice}->{ID},
    Invoker => 'RoomExists',
    Asyncronous => 0,
    Data => {
      ChannelName => $RoomName,
    },
  );
}


=head3 Lookup()

C<Lookup()> performs what is essentially a Rocket.Chat user data base lookup
using L<users.list|https://docs.rocket.chat/api/rest-api/methods/users/list>:
For a given array of email addresses it returns an array of Rocket.Chat user
objects. This is useful for finding the Rocket.Chat users corresponding to
OTOBO users. If you are only interested in the usernames, use
L<LookupUsernames()|/"LookupUsernames()">.

    my $LookupResult = $RocketChat->Lookup(
        Emails => ('hello@example.org', 'foo@bar.com');
    );

Returns:

    $LookupResult = {
        Success => 1,
        Data =>
            [
               {
                  'username' => 'bla',
                  '_id' => 'gxh3104',
                  ...
               },
               ...
            ],
    };

For structure of the user object also refer to the
L<Rocket.Chat documentation|https://docs.rocket.chat/api/rest-api/methods/users/list>.

=cut

sub Lookup {
  my ($Self, %Param) = @_;

  if(!IsArrayRefWithData($Param{Emails})) {
    return {
      Success => 0,
      ErrorMessage => 'Need Parameter Emails',
    };
  }

  return $Self->{Requester}->Run(
    WebserviceID => $Self->{Webservice}->{ID},
    Invoker => 'Lookup',
    Asyncronous => 0,
    Data => {
      Emails => $Param{Emails},
    },
  );
}

=head3 LookupUsernames()

Performs a L<Lookup()|/"Lookup()">, but transforms the return data so it only
contains an array of Rocket.Chat usernames.

    my $LookupResult = $RocketChat->LookupUsernames(
        Emails => ('hello@example.org', 'foo@bar.com');
    );

Returns:

    $LookupResult = {
        Success => 1,
        Data => [ 'foo', 'bar' ],
    };

=cut

sub LookupUsernames {
  my ($Self, %Param) = @_;

  my $Result = $Self->Lookup(%Param);

  # extracts usernames if successful
  if($Result->{Success}) {
    my @Names = map { $_->{'username'} } @{$Result->{Data}};
    return {
      Success => 1,
      Data => \@Names,
    };
  } else {
    return $Result;
  }
}

=head3 GroupCreate()

Creates a Rocket.Chat Group which a given list of members using
L<groups.create|https://docs.rocket.chat/api/rest-api/methods/groups/create>
As a side effect of how the Rocket.Chat REST API works, the user used to call
the API will also be added as a member automatically.

    my $GroupResult = $RocketChat->GroupCreate(
        GroupName => 'my-group',
        Members => ['list', 'of', 'usernames'],
    );

Instead of C<GroupName> also a C<TicketID> can be given. Then C<GroupCreate()>
will use L<GetRoomName()|/"GetRoomName()"> to figure out the C<GroupName>.

Returns:

    $GroupResult = {
        Success => 1,
        Data => {
            GroupID => 'gnGFLHne',
            Type => 'p' # always p unless Rocket.Chat is broken
        },
    };

=cut

sub GroupCreate {
  my ($Self, %Param) = @_;

  my $GroupName;

  if(IsStringWithData($Param{GroupName})) {
    $GroupName = $Param{GroupName};
  } elsif(IsInteger($Param{TicketID})) {
    $GroupName = $Self->GetRoomName($Param{TicketID});
  } else {
    return {
      Success => 0,
      ErrorMessage => 'Need either TicketID or GroupName parameter',
    }
  }

  return $Self->{Requester}->Run(
    WebserviceID => $Self->{Webservice}->{ID},
    Invoker => 'GroupCreate',
    Asyncronous => 0,
    Data => {
      ChannelName => $GroupName,
      Members => $Param{Members},
    },
  );
}

=head3 GroupAddOwner()

Adds sets a given user's role in a specified Rocket.Chat group to "Owner".
This is achieved using L<groups.addOwner|https://docs.rocket.chat/api/rest-api/methods/groups/addowner>.

    my $OwnerResult = $RC->GroupAddOwner(
      RoomName => $RoomName,
      Email => $OwnerEmail,
    );

If C<Email> is given, C<GroupAddOwner()> will perform a L<Lookup()|/"Lookup()">
to find out the C<_id> of the corresponding Rocket.Chat user. Alternatively
you can specify it directly using C<UserID>. Note that it is not possible to
give a Rocket.Chat user name, since the Rocket.Chat API doesn't accept user
names for this endpoint.

Use C<$OwnerResult-E<gt>{Success}> of the return ref.

=cut

sub GroupAddOwner {
  my ($Self, %Param) = @_;

  my $UserID;
  my $RoomID;

  if(IsStringWithData($Param{GroupID})) {
    $RoomID = $Param{GroupID};
  } else {
    my $RoomResult = $Self->RoomExists(%Param);
    unless($RoomResult->{Success}) {
      return {
        Success => 0,
        ErrorMessage => 'GroupAddOwner: ' . $RoomResult->{ErrorMessage},
      };
    }

    $RoomID = $RoomResult->{Data}->{RoomID};
  }

  if(IsStringWithData($Param{UserID})) {
    $UserID = $Param{UserID};
  } elsif(IsStringWithData($Param{Email})) {
    my $LookupResult = $Self->Lookup(
      Emails => [ $Param{Email}, ],
    );

    unless($LookupResult->{Success}) {
      return {
        Success => 0,
        ErrorMessage => 'GroupAddOwner: Could not perform Email Lookup: '
          . $LookupResult->{ErrorMessage},
      };
    }

    unless(IsArrayRefWithData($LookupResult->{Data})
      && @{$LookupResult->{Data}} == 1) {
      return {
        Success => 0,
        ErrorMessage => 'GroupAddOwner: Lookup didn\'t return Rocket.Chat user',
      };
    }

    $UserID = $LookupResult->{Data}->[0]->{'_id'};
  } else {
    return {
      Success => 0,
      ErrorMessage => 'Need either UserID or Email param',
    };
  }

  return $Self->{Requester}->Run(
    WebserviceID => $Self->{Webservice}->{ID},
    Invoker => 'GroupAddOwner',
    Data => {
      UserID => $UserID,
      RoomID => $RoomID,
    }
  );
}

=head3 GroupInvite()

Issues an invite to a Rocket.Chat channel via the Rocket.Chat API.

    my $InviteResult = $RC->GroupInvite(
      GroupID => 'ghx834Ngels8',
      UserID => '893keasXesa8',
    );

    if(!$InviteResult->{Success}) {
      …
    }

As returned C<Data> the C<group> structure of the response is
exposed. For more details see
L<the documentation for /groups.invite|https://docs.rocket.chat/api/rest-api/methods/groups/invite>.

=cut

sub GroupInvite {
  my ($Self, %Param) = @_;

  # maybe resolve usernames to user IDs
  # in the future here?

  return $Self->{Requester}->Run(
    WebserviceID => $Self->{Webservice}->{ID},
    Invoker => 'GroupInvite',
    Asyncronous => 0,
    Data => {
      GroupID => $Param{GroupID},
      UserID => $Param{UserID},
    },
  );
}

=head3 GroupMemberOf()

Checks if the Rocket.Chat user used by this module is member of a given
channel. Either the name of the desired group can be supplied via C<GroupName>
or the C<TicketID> for the desired OTOBO ticket chat channel.

This function is intended to be a low-privilege replacement for
L<RoomExists()|/RoomExists> if only rooms which the invoking user
is part of are of interest. Also note that this functions will only
return groups, not other types of rooms.

    my $MemberResult = $RC->GroupMemberOf(
      GroupName => 'my-group-name',
    );

Response:

    $MemberResult = {
       Success => 1,
       Data => {
           Exists => 1,
           RoomID => 'xng374nega', # only if Exists = 1
       },
    };

=cut

sub GroupMemberOf {
  my ($Self, %Param) = @_;
  my $RoomName;

  if(IsStringWithData($Param{GroupName})) {
    $RoomName = $Param{GroupName};
  } elsif(IsInteger($Param{TicketID})) {
    $RoomName = $Self->GetRoomName($Param{TicketID});
  } else {
    return {
      Success => 0,
      ErrorMessage => 'Need either TicketID or RoomName parameter',
    };
  }

  return $Self->{Requester}->Run(
    WebserviceID => $Self->{Webservice}->{ID},
    Invoker => 'GroupMemberOf',
    Asyncronous => 0,
    Data => {
      GroupName => $RoomName,
    },
  );
}

=head3 GroupMembers()

Returns the list of members of the group identified by a given C<GroupID>.

    my $MemberResult = $RC->GroupMembers(GroupID => 'xH83hcSea');

    $MemberResult = {
      Success => 1,
      Data => [ 'list', 'of', 'members' ],
    };

=cut

sub GroupMembers {
  my ($Self, %Param) = @_;

  return $Self->{Requester}->Run(
    WebserviceID => $Self->{Webservice}->{ID},
    Invoker => 'GroupMembers',
    Asyncronous => 0,
    Data => {
      GroupID => $Param{GroupID},
    },
  );
}

=head3 GroupSetAnnouncement()

Set the announcement of a Rocket.Chat private channel (group).

    my $AnnouncementResult = $RC->GroupSetAnnouncement
        GroupID => 'some-string-id',
        Announcement => 'My Announcement Text',
    );

Of the resulting value, mostly the C<$AnnouncementResult-E<gt>{Success}>
is interesting to check if the action succeeded.

=cut

sub GroupSetAnnouncement {
  my ($Self, %Param) = @_;

  return $Self->{Requester}->Run(
    WebserviceID => $Self->{Webservice}->{ID},
    Invoker => 'GroupSetAnnouncement',
    Data => {
      GroupID => $Param{GroupID},
      Announcement => $Param{Announcement},
    }
  );
}

=head3 UserInfo()

Retrieves information about a certain Rocket.Chat user.
Main intention is to use this to determine user ids, but
also other information (depending on the invoking user's
permissions are available. For more information on the
resulting structure and how it differs depending on
permissions see the
L<Documentation of the /users.info endpoint|https://docs.rocket.chat/api/rest-api/methods/users/info>.

    my $UserResult = $RC->UserInfo(Username => 'lukas');

    $UserResult = {
      'Data' => {
        '_id' => '6sFDd6DGoAa3AjLpX',
        'active' => 1,
        'name' => 'Lukas',
        'status' => 'online',
        'type' => 'user',
        'username' => 'lukas',
        'utcOffset' => 1
      },
      'Success' => 1
    };

=cut

sub UserInfo {
  my ($Self, %Param) = @_;

  return $Self->{Requester}->Run(
    WebserviceID => $Self->{Webservice}->{ID},
    Invoker => 'UserInfo',
    Data => {
      Username => $Param{Username},
    },
  );
}

=head2 General Helpers

Split out functionality common to multiple modules.

=head3 RocketChatURL()

=cut

sub RocketChatURL {
  my ($Self, $Path) = @_;

  my $RCURL = $Self->{Webservice}->{Config}->{RemoteSystem};

  if(!IsStringWithData($Path)) {
    $Path = '';
  } elsif(!($RCURL =~ m/\/$/ || $Path =~ m/^\//)) {
    $Path = '/' . $Path;
  }

  return $RCURL . $Path;
}

=head3 GetRoomName()

Given a TicketID return the name of the Rocket.Chat group corresponding to
the Ticket. Returns undef if an error occurs. Typical usage:

    my $GroupName = $RocketChat->GetRoomName($Param{TicketID});

=cut

sub GetRoomName {
  my ($Self, $Name) = @_;

  if($Name) {
    my %GeneralConfig = $Self->{SysConfigObject}->SettingGet(
      Name => GENERAL_CONFIG,
    );
    my $ChannelPrefix = $GeneralConfig{EffectiveValue}->{ChannelPrefix};

    unless(defined $ChannelPrefix) {
      # default if something is wrong with config
      my $ChannelPrefix = 'otobo-chat-ticket-';
    }

    return $ChannelPrefix . $Name;
  } else {
    return;
  }
}


=head3 IsEmailAddress()

Very simple sanity check if a given string is an email address. Should be
used across the module to avoid situations which one module would accept
an input and another one wouldn't. Also useful for distinguishing email
addresses from special OTOBO "addresses" like queue names.

    unless($RocketChat->IsEmailAddress('hello@example.org') {
        # wtf?
    }

=cut

sub IsEmailAddress {
  my ($Self, $Address) = @_;
  # TODO rework or drop reflecting switch to EmailParser
  return $Address =~ /.+@.+/;
}

=head2 OTOBO Interaction Helpers

Helper functions used in the Rocket.Chat extension to interact with OTOBO,
mostly retrieving data.

=head3 GetTicketOwner()

Returns the user that owns a ticket, undef if an error occurs.

    my $Owner = $RocketChat->GetTicketOwner(TicketID => 1);

    print $Owner{UserEmail};

=cut

sub GetTicketOwner {
  my ($Self, %Param) = @_;

  unless($Param{TicketID}) {
    return;
  }

  my ($OwnerID, $Owner) = $Self->{TicketObject}->OwnerCheck(
    TicketID => $Param{TicketID}
  );

  unless($OwnerID) {
    return;
  }

  my $UserObject = $Kernel::OM->Get('Kernel::System::User');
  my %OwnerUser = $UserObject->GetUserData(
    UserID => $OwnerID
  );

  return %OwnerUser;
}

=head3 GetInvolvedEmails()

Collect Emails related to a ticket from various sources (Involved Agents,
Customer User Email, Owner Email, Email Addresses from Article Headers, …).
Returns an array of emails which may contain duplicates, on error the array is
empty.

 my @Emails = $RocketChat->GetInvolvedEmails(
     TicketID => 2,
     UserID => 3,
     Output => 'Email',
 );

Its behavior can be modified by the following values in C<GENERAL_CONFIG> (see
also L<Kernel::System::RocketChat::Util>):

=over

=item *

C<IncludeArticleEmails>: if false, C<GetInvolvedEmails()> will ignore Articles (i. e.
emails and similar messages) associated with the ticket completely and only use the
metadata of the ticket itself.

=item *

C<IncludeCcEmails>: if true, C<GetInvolvedEmails()> will also return email addresses which
are found in the C<Cc> header of articles.

=item *

C<IncludeHiddenEmails>: if true, C<GetInvolvedEmails()> will also return email addresses
which are contained in articles that are not visible to the customer.

=back

The C<Output> parameter can be used to return usernames of OTOBO users instead of email addresses
if that is desired by using C<Output =E<gt> 'Username'>.

=cut

sub GetInvolvedEmails {
  my ($Self, %Param) = @_;

  my $OutputUsers = 0;

  unless(defined $Param{TicketID}) {
    $Self->{Log}->Log(
      Priority => 'error',
      Message => 'GetInvolvedEmails: missing required TicketID parameter'
    );
    return ();
  }

  unless(defined $Param{UserID}) {
    $Self->{Log}->Log(
      Priority => 'error',
      Message => 'GetInvolvedEmails: missing required UserID parameter'
    );
    return ();
  }

  # Output types:
  #
  # Output => 'Username'
  # Output => 'Email'    (default)
  if(IsStringWithData($Param{Output}) && $Param{Output} eq 'Username') {
    $OutputUsers = 1;
  }

  my @InvolvedEmails = ();
  my $CustomerUserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');
  my $ArticleObject = $Kernel::OM->Get('Kernel::System::Ticket::Article');

  my %Ticket = $Self->{TicketObject}->TicketGet(
    TicketID => $Param{TicketID},
    UserID => $Param{UserID},
  );

  unless(%Ticket) {
    $Self->{Log}->Log(
      Priority => 'error',
      Message => 'GetInvolvedEmails: TicketGet didn\'t return valid ticket hash ref'
    );
    return ();
  }

  # Add involved agents
  my @InvolvedAgents = $Self->{TicketObject}->TicketInvolvedAgentsList(TicketID => $Param{TicketID});

  foreach my $Agent (@InvolvedAgents) {
    if($OutputUsers) {
      push @InvolvedEmails, $Agent->{UserLogin};
    } else {
      push @InvolvedEmails, $Agent->{UserEmail};
    }
  }

  # If the ticket has a customer user set, add their email
  if(defined $Ticket{CustomerUserID}) {
    my %CustomerUser = $CustomerUserObject->CustomerUserDataGet(
      User => $Ticket{CustomerUserID},
    );

    if($OutputUsers && exists $CustomerUser{UserLogin}) {
      push @InvolvedEmails, $CustomerUser{UserLogin};
    }

    if(!$OutputUsers && exists $CustomerUser{UserEmail}) {
      push @InvolvedEmails, $CustomerUser{UserEmail};
    }
  }

  my %GeneralConfig = $Self->{SysConfigObject}->SettingGet(
    Name => GENERAL_CONFIG,
  );

  if(!$OutputUsers && $GeneralConfig{EffectiveValue}->{IncludeArticleEmails}) {
    # Get Email addresses from Ticket's articles
    # Only MIME based Article backends are supported
    # TODO Support for Chat backend? low prio
    my @Articles = $ArticleObject->ArticleList(
      TicketID => $Param{TicketID},
    );

    foreach my $Article (@Articles) {
      my $BackendObject = $ArticleObject->BackendForArticle(%{$Article});
      my $ChannelName = $BackendObject->ChannelNameGet();

      if($ChannelName =~ m/^(Email|Phone|Internal)$/) {
        my %ArticleData = $BackendObject->ArticleGet(%{$Article});

        # Don't include article's emails if IncludeHiddenEmails is false
        # and article is not visible for customers
        if($GeneralConfig{EffectiveValue}->{IncludeHiddenEmails}
          || $ArticleData{IsVisibleForCustomer}) {

          my @ArticleEmails = ();
          push @ArticleEmails, $Self->_HeaderEmails($ArticleData{To});
          push @ArticleEmails, $Self->_HeaderEmails($ArticleData{From});

          if($GeneralConfig{EffectiveValue}->{IncludeCcEmails}) {
            push @ArticleEmails, $Self->_HeaderEmails($ArticleData{Cc});
          }

          foreach my $Email (@ArticleEmails) {
            # there will be some undefs in the array due to queue names
            # used in the To header for example. We filter them out here
            if(IsStringWithData($Email)) {
              push @InvolvedEmails, $Email;
            }
          }
        }
      }
    }
  }

  # Add Owner just to be sure
  my %Owner = $Self->GetTicketOwner(
    TicketID => $Param{TicketID}
  );

  if(!$OutputUsers && exists $Owner{UserEmail}) {
    push @InvolvedEmails, $Owner{UserEmail};
  }

  if($OutputUsers && exists $Owner{UserLogin}) {
    push @InvolvedEmails, $Owner{UserLogin};
  }

  return @InvolvedEmails;
}

=head3 AccessCheck()

Checks if an OTOBO user may perform Rocket.Chat related actions
for a given ticket. Such actions may be creating or deleting
of a group. Note however that every user may be allowed to be
presented a link or be redirected to an already existing group,
since Rocket.Chat will handle access control for us in that case.

    my $AccessOk = $RocketChat->AccessCheck(
        UserID => 3,
        TicketID => 4,
    );

    unless($AccessOk) {
      return "no access";
    }

Returns C<undef> on error, C<1> or C<0> corresponding to access.

=cut

sub AccessCheck {
  my ($Self, %Param) = @_;

  unless($Param{UserID}) {
    return;
  }

  unless($Param{TicketID}) {
    return;
  }

  # TODO allow to switch between access schemes in config
  # TODO always allow admin (nice for testing)

  # (currently only) method check if user is ticket owner
  my ($OwnerID, $Owner) = $Self->{TicketObject}->OwnerCheck(
    TicketID => $Param{TicketID}
  );

  return ($OwnerID == $Param{UserID});
}

=head2 Internal Helpers

Helpers only used in this module.

=head3 _HeaderEmails()

Helper function wrapping Kernel::System::EmailParser: Given a Header, we first
call SplitAddressLine to separate (if necessary) multiple addresses in the
header. Then we call GetEmailAddress on each one of them to separate the
email address from the real name.

This function will always return an array which may contain strings and
undefs (if an email address was invalid).

Example usage:

    my @Addresses = $RocketChat->_HeaderEmails('Juergen Weber <juergen.qeber@air.com>, me@example.com');

=cut

sub _HeaderEmails {
  my ($Self, $Header) = @_;

  if(!IsStringWithData($Header)) {
    return ();
  }

  my @Addresses = $Self->{EmailParser}->SplitAddressLine(
    Line => $Header,
  );

  foreach my $Address (@Addresses) {
    $Address = $Self->{EmailParser}->GetEmailAddress(
      Email => $Address,
    );
  }

  return @Addresses;
}

1;
