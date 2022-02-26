# --
# Copyright © 2020 Lukas Epple, Universität Augsburg
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::Modules::AgentTicketRocketChat;

use strict;
use warnings;

use Kernel::Language qw(Translatable);
use Kernel::System::VariableCheck qw(IsStringWithData IsInteger IsHashRefWithData);

use Kernel::System::RocketChat::Util qw(IsExtensionActive GENERAL_CONFIG);

use CGI;

our $ObjectManagerDisabled = 1;

sub new {
  my ($Type, %Param) = @_;

  my $Self = {%Param};
  bless($Self, $Type);

  return $Self;
}

sub Run {
  my ($Self, %Param) = @_;

  my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

  my $SysConfigObject = $Kernel::OM->Get('Kernel::System::SysConfig');
  my $IsActive = IsExtensionActive(
    SysConfigObject => $SysConfigObject,
  );

  # bail out if the extension is not active
  unless($IsActive) {
    return $LayoutObject->ErrorScreen(
      Message => Translatable('The Rocket.Chat Extension is not activated'),
      Comment => Translatable('Please contact the administrator.'),
    );
  }

  my $RC = $Kernel::OM->Get('Kernel::System::RocketChat');

  if (!$Self->{TicketID}) {
    return $LayoutObject->ErrorScreen(
      Message => Translatable('Can\'t do anything, no TicketID is given!'),
      Comment => Translatable('Please contact the administrator.'),
    );
  }

  my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

  my $RoomName = $RC->GetRoomName($Self->{TicketID});

  if(!$Self->{UserID}) {
    return $LayoutObject->ErrorScreen(
      Message => Translatable('Can\'t do anything, got no UserID!'),
      Comment => Translatable('Please contact the administrator.'),
    );
  }

  if(!IsStringWithData($Self->{Subaction})) {
    return $LayoutObject->ErrorScreen(
      Message => Translateable('Missing subaction!'),
      Comment => Translatable('Please contact the administrator.'),
    );
  } elsif($Self->{Subaction} eq 'Create') {
    my $ExistsResult = $RC->GroupMemberOf(
      GroupName => $RoomName,
    );

    if(!$ExistsResult->{Success}) {
      return $LayoutObject->ErrorScreen(
        Message => Translatable('Couldn\'t communicate with the Rocket.Chat API!'),
        Comment => $ExistsResult->{ErrorMessage},
      );
    }

    if(!$ExistsResult->{Data}->{Exists}) {
      # Check if user may open channels
      my $AccessOk = $RC->AccessCheck(
        UserID => $Self->{UserID},
        TicketID => $Self->{TicketID},
      );

      unless($AccessOk) {
        return $LayoutObject->ErrorScreen(
          Message => Translatable('You are not allowed to perform this action!'),
          Comment => Translatable('If you believe this is an error, contact the administrator.'),
        );
      }

      # Check if username discovery is to be used, but default to email
      my %GeneralConfig = $SysConfigObject->SettingGet(
        Name => GENERAL_CONFIG
      );

      my $DiscoveryType = 'Email';
      if(IsStringWithData($GeneralConfig{EffectiveValue}->{UserDiscoveryType})) {
        $DiscoveryType = $GeneralConfig{EffectiveValue}->{UserDiscoveryType};
      }

      my @InvolvedUsers = $RC->GetInvolvedEmails(
        TicketID => $Self->{TicketID},
        UserID => $Self->{UserID},
        Output => $DiscoveryType,
      );

      if(@InvolvedUsers > 0) {
        my @ChannelMembers = ();
        my @ChannelMemberIDs = (); # only for InviteUsers

        if($DiscoveryType eq 'Username') {
          my @OTRSUsernames = $Self->_Deduplicate(@InvolvedUsers);

          # find all OTOBO users that exist in Rocket.Chat
          # and if necessary extract their user id
          foreach my $User (@OTRSUsernames) {
            my $RCUserInfo = $RC->UserInfo(Username => $User);

            # we assume if the API call fails it is because the user doesn't exist
            if($RCUserInfo->{Success}) {
              push @ChannelMembers, $User;
              if($GeneralConfig{EffectiveValue}->{InviteUsers}) {
                push @ChannelMemberIDs, $RCUserInfo->{Data}->{'_id'};
              }
            }
          }

          # bail out if we have no matching users
          if(@ChannelMembers <= 0) {
            return $LayoutObject->ErrorScreen(
              Message => Translatable('Found no Rocket.Chat accounts associated with this ticket'),
              Comment => Translatable('Make sure the OTOBO and Rocket.Chat usernames match!'),
            );
          }
        } else {
          my $LookupResult = $RC->LookupUsernames(
            Emails => \@InvolvedUsers,
          );

          if(!$LookupResult->{Success}) {
            return $LayoutObject->ErrorScreen(
              Message => Translatable('Couldn\'t communicate with the Rocket.Chat API!'),
              Comment => $LookupResult->{ErrorMessage},
            );
          }

          if($LookupResult->{Data} <= 0) {
            return $LayoutObject->ErrorScreen(
              Message => Translatable('Found no Rocket.Chat accounts associated with this ticket'),
              Comment => Translatable('Make sure the OTOBO and Rocket.Chat email addresses match!'),
            );
          }

          @ChannelMembers = @{$LookupResult->{Data}};

          # if we are using InviteUsers get the user ids
          if($GeneralConfig{EffectiveValue}->{InviteUsers}) {
            foreach my $User (@ChannelMembers) {
              my $RCUserInfo = $RC->UserInfo(Username => $User);

              if($RCUserInfo->{Success}) {
                push @ChannelMemberIDs, $RCUserInfo->{Data}->{'_id'};
              }
            }
          }
        }

        my $CreateResult = {
          Success => 0,
        };

        if($GeneralConfig{EffectiveValue}->{InviteUsers}) {
          $CreateResult = $RC->GroupCreate(
            GroupName => $RoomName,
            Members => [],
          );
        } else {
          $CreateResult = $RC->GroupCreate(
            GroupName => $RoomName,
            Members => \@ChannelMembers,
          );
        }

        if(!$CreateResult->{Success}) {
          return $LayoutObject->ErrorScreen(
            Message => Translatable('Couldn\'t communicate with the Rocket.Chat API!'),
            Comment => $CreateResult->{ErrorMessage},
          );
        }

        # get group id from CreateResult for future use
        my $RoomID = $CreateResult->{Data}->{GroupID};

        if($GeneralConfig{EffectiveValue}->{InviteUsers}) {
          foreach my $ID (@ChannelMemberIDs) {
            my $InviteResult = $RC->GroupInvite(
              GroupID => $RoomID,
              UserID => $ID,
            );

            if(!$InviteResult->{Success}) {
              return $LayoutObject->ErrorScreen(
                Message => Translatable('Couldn\'t invite a Rocket.Chat user to the ticket channel'),
                Comment => Translatable('Please contact the administrator.'),
              );
            }
          }
        }

        my $Announcement;
        my $CGI = CGI->new();

        my %Ticket = $TicketObject->TicketGet(
          TicketID => $Self->{TicketID},
          UserID => $Self->{UserID},
        );

        if(IsStringWithData($Ticket{Title})) {
          $Announcement = $LayoutObject->{LanguageObject}
            ->Translate('Ticket Title: %s | ', $Ticket{Title});
        }

        my $TicketLink = $CGI->url();
        $TicketLink =  $TicketLink . '?Action=AgentTicketZoom;TicketID=' . $Self->{TicketID};

        $Announcement = $Announcement . $LayoutObject->{LanguageObject}
          ->Translate('Link to Ticket: %s', $TicketLink);

        my $AnnouncementResult = $RC->GroupSetAnnouncement(
          GroupID => $RoomID,
          Announcement => $Announcement,
        );

        # Make the ticket owner channel owner
        my %Owner = $RC->GetTicketOwner(
          TicketID => $Self->{TicketID},
        );

        my $OwnerResult = {
          Success => 0,
        };

        if($DiscoveryType eq 'Username') {
          my $RCUserInfo = $RC->UserInfo(
            Username => $Owner{UserLogin},
          );

          unless($RCUserInfo->{Success}) {
            return $LayoutObject->ErrorScreen(
              Message => Translatable('Couldn\'t get user info for the ticket owner from Rocket.Chat'),
              Comment => Translatable('Please contact the administrator.'),
            );
          }

          $OwnerResult = $RC->GroupAddOwner(
            GroupID => $RoomID,
            UserID => $RCUserInfo->{Data}->{'_id'},
          );
        } else {
          if(IsStringWithData($Owner{UserEmail})) {
            $OwnerResult = $RC->GroupAddOwner(
              GroupID => $RoomID,
              Email => $Owner{UserEmail},
            );
          }
        }

        # ignore possible GroupAddOwner error if we invite users
        if(!$OwnerResult->{Success}
          && !$GeneralConfig{EffectiveValue}->{InviteUsers}) {
          return $LayoutObject->ErrorScreen(
            Message => Translatable('Could not make the Ticket Owner Channel Owner, make sure they have a matching Rocket.Chat account!'),
            Comment => Translatable('Please contact the administrator.'),
          );
        }
      } else {
        return $LayoutObject->ErrorScreen(
          Message => Translatable('Didn\'t find any Users associated with this ticket'),
          Comment => Translatable('If you believe this is an error, contact the administrator.'),
        );
      }
    }

    # redirect to group which either already existed
    # or has been created (on error we return earlier)
    return $LayoutObject->Redirect(
      ExtURL => $RC->RocketChatURL('group/' . $RoomName),
    );
  } elsif($Self->{Subaction} eq 'Delete') {
    return $LayoutObject->ErrorScreen(
      Message => Translatable('Delete Subaction not yet implemented!'),
      Comment => Translatable('Please return later'),
    );

  } else {
    return $LayoutObject->ErrorScreen(
      Message => Translatable('Invalid Subaction'),
      Comment => Translatable('Please contact the administrator.'),
    );
  }

  return $LayoutObject->Redirect(OP => "Action=AgentTicketZoom;TicketID=$Self->{TicketID}");
}

sub _Deduplicate {
  # https://perldoc.perl.org/perlfaq4#How-can-I-remove-duplicate-elements-from-a-list-or-array%3f
  my ($Self, @duplicates) = @_;
  my %seen = ();
  return (grep { ! $seen{ $_ }++ } @duplicates);
}

1;
