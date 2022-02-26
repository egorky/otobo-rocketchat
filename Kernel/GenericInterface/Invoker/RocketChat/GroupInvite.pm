# --
# Copyright © 2020 Lukas Epple, Universität Augsburg
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::GenericInterface::Invoker::RocketChat::GroupInvite;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsStringWithData);

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

  if(!IsStringWithData($Param{Data}->{UserID})) {
    return $Self->{DebuggerObject}->Error(
      Summary => 'Missing param UserID which is required for GroupInvite invoker',
    );
  }

  if(!IsStringWithData($Param{Data}->{GroupID})) {
    return $Self->{DebuggerObject}->Error(
      Summary => 'Missing param GroupID which is required for GroupInvite invoker',
    );
  }

  return {
    Success => 1,
    Data => {
      userId => $Param{Data}->{UserID},
      roomId => $Param{Data}->{GroupID},
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

  # boolean handling is still unreliable in OTOBO
  # if(!$Param{Data}->{'success'}) {
  #   return $Self->{DebuggerObject}->Error(
  #     Summary => 'Rocket.Chat API reports error',
  #   );
  # }

  return {
    Success => 1,
    Data => $Param{Data}->{'group'},
  };
}

1;
