# --
# Copyright © 2020 Lukas Epple, Universität Augsburg
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::GenericInterface::Invoker::RocketChat::GroupAddOwner;

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

  unless(IsStringWithData($Param{Data}->{RoomID})) {
    return $Self->{DebuggerObject}->Error(
      Summary => "Param RoomID missing or malformed",
    );
  }

  unless(IsStringWithData($Param{Data}->{UserID})) {
    return $Self->{DebuggerObject}->Error(
      Summary => "Param UserID missing or malformed",
    );
  }

  return {
    Success => 1,
    Data => {
      'roomId' => $Param{Data}->{RoomID},
      'userId' => $Param{Data}->{UserID},
    }
  };
}

sub HandleResponse {
  my ($Self, %Param) = @_;

  if(!$Param{ResponseSuccess} || !$Param{Data}->{'success'}) {
    # pass through error
    if(!IsStringWithData($Param{ResponseErrorMessage})) {
      return $Self->{DebuggerObject}->Error(
        Summary => 'Got response error, no message given',
      );
    }

    return {
      Success => 0,
      ErrorMessage => $Param{ResponseErrorMessage}
    };
  }

  return {
    Success => 1,
    Data => {
      Success => $Param{Data}->{'success'},
    },
  }
}

1;
