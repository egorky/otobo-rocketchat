# --
# Kernel/Output/HTML/TicketMenu/RocketChat.pm
# Copyright © 2020 Lukas Epple, Universität Augsburg
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::Output::HTML::TicketMenu::RocketChat;

use parent 'Kernel::Output::HTML::Base';

use strict;
use warnings;

use Kernel::System::RocketChat::Util qw(IsExtensionActive GENERAL_CONFIG);

our @ObjectDependencies = (
  'Kernel::System::Log',
  'Kernel::Config',
  'Kernel::System::Ticket',
  'Kernel::System::RocketChat',
  'Kernel::System::SysConfig',
  'Kernel::Language',
);

sub Run {
  my ($Self, %Param) = @_;

  my $LogObject = $Kernel::OM->Get('Kernel::System::Log');
  my $SysConfigObject = $Kernel::OM->Get('Kernel::System::SysConfig');
  my $LanguageObject = $Kernel::OM->Get('Kernel::Language');

  my $IsActive = IsExtensionActive(
    SysConfigObject => $SysConfigObject,
  );

  # bail out if extension is not configured
  unless($IsActive) {
    return;
  }

  if(!$Param{Ticket}) {
    $LogObject->Log(
      Priority => 'error',
      Message => 'Missing Ticket'
    );
    return;
  }

  # Check if action is registered
  if($Param{Config}->{Action}) {
    my $Module = $Kernel::OM->Get('Kernel::Config')->Get('Frontend::Module')->{ $Param{Config}->{Action} };
    return if !$Module;
  }

  my $RC = $Kernel::OM->Get('Kernel::System::RocketChat');

  my %GeneralConfig = $SysConfigObject->SettingGet(
    Name => GENERAL_CONFIG,
  );

  my $Name;
  my $Description;

  # if the room exists we should show the menu entry
  # to everyone — only creation is restricted!
  my $ShowEntryAnyAccess = 0;

  # if dynamic: Check if channel has already been created
  if($GeneralConfig{EffectiveValue}->{DynamicTicketMenu}) {
    my $ExistsResult = $RC->GroupMemberOf(
      TicketID => $Param{Ticket}->{TicketID},
    );

    # RoomExists does seldomly fail. If it does we assume the channel doesn't
    # exist and let AgentTicketRocketChat deal with any issues.
    if($ExistsResult->{Data}->{Exists}) {
      $Name = $LanguageObject->Translate('Go to Rocket.Chat Channel');
      $Description = $LanguageObject->Translate('Go to Rocket.Chat Channel for this ticket');
      $ShowEntryAnyAccess = 1;
    } else {
      $Name = $LanguageObject->Translate('Open Rocket.Chat Channel');
      $Description = $LanguageObject->Translate('Open Rocket.Chat Channel for this ticket');
      $ShowEntryAnyAccess = 0;
    }
  } else {
    $Name = $LanguageObject->Translate('Open/go to Rocket.Chat Channel');
    $Description = $LanguageObject->Translate('Open new or go to existing Rocket.Chat Channel for this ticket');
    $ShowEntryAnyAccess = 1;
  }

  # Don't show users who may not create a channel the option to do so
  # (they still will see the go to channel link if it exists)
  my $AccessOk = $RC->AccessCheck(
    UserID => $Self->{UserID},
    TicketID => $Param{Ticket}->{TicketID},
  );

  unless($AccessOk || $ShowEntryAnyAccess) {
    return;
  }

  return {
    %{ $Param{Config} },
    %{ $Param{Ticket} },
    %Param,
    Name => $Name,
    Description => $Description,
    Link => 'Action=AgentTicketRocketChat;Subaction=Create;TicketID=[% Data.TicketID | uri %]',
  };
}

1;
