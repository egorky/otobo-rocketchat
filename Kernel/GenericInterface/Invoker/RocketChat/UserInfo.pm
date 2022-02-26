# --
# Copyright © 2020 Lukas Epple, Universität Augsburg
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::GenericInterface::Invoker::RocketChat::UserInfo;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsStringWithData IsHashRefWithData);

our $ObjectManagerDisabled = 1;

sub new {
  my ($Type, %Param) = @_;

  my $Self = {};

  bless($Self, $Type);

  if(!$Param{DebuggerObject}) {
    return {
      Success => 0,
      ErrorMessage => "Got no DebuggerObject",
    };
  }

  $Self->{DebuggerObject} = $Param{DebuggerObject};

  return $Self;
}

sub PrepareRequest {
  my ($Self, %Param) = @_;

  if(!IsStringWithData($Param{Data}->{Username})) {
    return $Self->{DebuggerObject}->Error(
      Summary => 'Missing param Username which is required for UserInfo invoker',
    );
  }

  return {
    Success => 1,
    Data => {
      username => $Param{Data}->{Username},
    },
  };
}

sub HandleResponse {
  my ($Self, %Param) = @_;
  # pass through error
  if(!$Param{ResponseSuccess}) {
    return {
      Success => 0,
      ErrorMessage => $Param{ResponseErrorMessage},
    };
  }

  # Unfortunately boolean handling is still unreliable in OTOBO
  # if(!$Param{Data}->{'success'}) {
  #   return $Self->{DebuggerObject}->Error(
  #     Summary => 'Rocket.Chat API reports error',
  #   );
  # }

  if(!IsHashRefWithData($Param{Data}->{'user'})) {
    return $Self->{DebuggerObject}->Error(
      Summary => 'Unexpected response: missing or malformed field user',
    );
  }

  return {
    Success => 1,
    Data => $Param{Data}->{'user'},
  };
}

1;
