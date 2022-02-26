# --
# Copyright © 2020 Lukas Epple, Universität Augsburg
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::GenericInterface::Invoker::RocketChat::GroupMembers;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsStringWithData IsNumber IsArrayRefWithData);

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

  if(!IsStringWithData($Param{Data}->{GroupID})) {
    return $Self->{DebuggerObject}->Error(
      Summary => 'Missing param GroupID which is required for GroupMembers invoker',
    );
  }

  return {
    Success => 1,
    Data => {
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

  if(!IsNumber($Param{Data}->{'count'})) {
    return $Self->{DebuggerObject}->Error(
      Summary => 'Unexpected response: missing or malformed field count',
    );
  }

  if($Param{Data}->{'count'} <= 0) {
    return {
      Success => 1,
      Data => [],
    };
  } else {
    if(!IsArrayRefWithData($Param{Data}->{'members'})) {
      return $Self->{DebuggerObject}->Error(
        Summary => 'Unexpected response: missing or malformed field members',
      );
    }

    return {
      Success => 1,
      Data => $Param{Data}->{'members'},
    };
  }
}

1;
