# --
# Copyright © 2020 Lukas Epple, Universität Augsburg
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::GenericInterface::Invoker::RocketChat::GroupSetAnnouncement;

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

  my $Request;

  if(!IsStringWithData($Param{Data}->{GroupID})) {
    return $Self->{DebuggerObject}->Error(
      Summary => "Got no GroupID which is required for GroupSetAnnouncement action"
    );
  }

  if(!IsStringWithData($Param{Data}->{Announcement})) {
    return $Self->{DebuggerObject}->Error(
      Summary => "Got no Announcement which is required for GroupSetAnnouncement action"
    );
  }

  $Request = {
    'roomId' => $Param{Data}->{GroupID},
    'announcement' => $Param{Data}->{Announcement},
  };

  return {
    Success => 1,
    Data => $Request,
  };
}

sub HandleResponse {
  my ($Self, %Param) = @_;

  if(!$Param{ResponseSuccess}) {
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

  my $Response = {
    Announcement => $Param{Data}->{'announcement'},
    Success => $Param{Data}->{'success'},
  };

  return {
    Success => 1,
    Data => $Response,
  };
}

1;
