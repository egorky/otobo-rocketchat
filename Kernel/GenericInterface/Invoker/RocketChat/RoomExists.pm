# --
# Copyright © 2020 Lukas Epple, Universität Augsburg
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::GenericInterface::Invoker::RocketChat::RoomExists;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsStringWithData IsArrayRefWithData IsNumber);

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

  if(!IsStringWithData($Param{Data}->{ChannelName})) {
    return $Self->{DebuggerObject}->Error(
      Summary => "Got no ChannelName which is required for RoomExists action"
    );
  }

  $Request = {
    'filter' => $Param{Data}->{ChannelName},
  };

  # let HandleResponse know about the ChannelName
  $Self->{ChannelName} = $Param{Data}->{ChannelName};

  return {
    Success => 1,
    Data => $Request,
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

  my $Response;

  if(!IsNumber($Param{Data}->{'count'})) {
    return {
      Success => 0,
      ErrorMessage => 'Unexpected Response',
    };
  }

  if($Param{Data}->{'count'} == 0) {
    $Response->{Exists} = 0;
  } else {
    if(IsArrayRefWithData($Param{Data}->{'rooms'})) {
      my $Found;
      SEARCH:
      foreach my $Room (@{$Param{Data}->{'rooms'}}) {
        if($Room->{'name'} eq $Self->{ChannelName}) {
          $Response->{Exists} = 1;
          $Response->{Type} = $Room->{'t'};
          $Response->{RoomID} = $Room->{'_id'};
          $Found = 1;
          last SEARCH;
        }
      }

      if(!$Found) {
        $Response->{Exists} = 0;
      }
    } else {
      return {
        Success => 0,
        ErrorMessage => 'Unexpected Response',
      };
    }
  }

  return {
    Success => 1,
    Data => $Response,
  };
}

1;
