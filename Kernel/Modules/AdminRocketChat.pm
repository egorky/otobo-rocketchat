# --
# Copyright © 2020 Lukas Epple, Universität Augsburg
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::Modules::AdminRocketChat;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsNumber IsHashRefWithData IsStringWithData);
use Kernel::Language qw(Translatable);

use Kernel::System::RocketChat::Util qw(:all);

our $ObjectManagerDisabled = 1;

sub new {
  my ($Type, %Param) = @_;

  my $Self = {%Param};
  bless($Self, $Type);

  $Self->{LayoutObject} = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
  $Self->{Sysconfig} = $Kernel::OM->Get('Kernel::System::SysConfig');
  $Self->{ParamObject} = $Kernel::OM->Get('Kernel::System::Web::Request');
  $Self->{WebserviceObject} = $Kernel::OM->Get('Kernel::System::GenericInterface::Webservice');
  $Self->{RequesterObject} = $Kernel::OM->Get('Kernel::GenericInterface::Requester');

  # Action and Subaction are magically populated
  $Self->{Error} = $Self->{ParamObject}->GetParam(Param => 'Error');

  return $Self;
}

sub Run {
  my ($Self, %Param) = @_;

  # Possible Actions:
  #
  # * Default (Change)
  #   * If no Webservice, show link to SetupWebservice
  #   * Otherwise Configure screen, submits to ChangeAction
  # * SetupWebservice (submits to SetupWebserviceAction)
  #   Get necessary info to initially create Webservice
  # * DeleteWebservice (submits to DeleteWebserviceAction)
  #   Show confirmation screen

  my %WebserviceConfig = $Self->{Sysconfig}->SettingGet(
    Name => WEBSERVICE_CONFIG,
  );

  my $Output = $Self->{LayoutObject}->Header();
  $Output .= $Self->{LayoutObject}->NavigationBar();

  # show errors if any
  if($Self->{Error}) {
    my $ErrorMessage = undef;

    my $WebservicePrefix = 'Error while creating the Webservice: ';

    if($Self->{Error} eq 'AuthError') {
      $ErrorMessage = $WebservicePrefix .
        'Couldn\'t authenticate! Are the Rocket.Chat URLs and credentials correct?';
    } elsif($Self->{Error} eq 'UpdateError') {
      $ErrorMessage = $WebservicePrefix .
        'Couldn\'t update the Webservice and/or System Configuration. ' .
        'Is something wrong with your OTOBO instance?';
    } elsif($Self->{Error} eq 'ChannelPrefixError') {
      $ErrorMessage = 'Channel Prefix may only contain alphanumeric characters and "-_."';
    }

    if(defined $ErrorMessage) {
      $Output .= $Self->{LayoutObject}->Notify(
        Priority => 'Error',
        Info => Translatable($ErrorMessage),
      );
    }
  }


  $Self->{LayoutObject}->Block(
    Name => 'ActionList',
  );

  if(rindex($Self->{Subaction}, 'Action') > -1) {
    # Is a form request, do CSRF protection
    $Self->{LayoutObject}->ChallengeTokenCheck();
  }

  if(!$Self->{UserID}) {
    return $Self->{LayoutObject}->ErrorScreen(
      Message => Translatable('Can\'t do anything, got no UserID!'),
      Comment => Translatable('Please contact the administrator.'),
    );
  }

  if($Self->{Subaction} eq 'ChangeAction') {
    my %Form;
    my $Error = '';

    # get params
    for my $Name (qw(Enable ChannelPrefix InviteUsers UserDiscoveryType IncludeArticleEmails IncludeCcEmails IncludeHiddenEmails Submit DynamicTicketMenu)) {
      my $p = $Self->{ParamObject}->GetParam(Param => $Name);
      if($p) {
        $Form{$Name} = $p;
      }
    }

    # check for submit button
    unless($Form{Submit} eq 'Save') {
      return $Self->{LayoutObject}->ErrorScreen(
        Message => Translatable('Save Request invalid'),
      );
    }

    my %OldSettings = $Self->{Sysconfig}->SettingGet(
      Name => GENERAL_CONFIG,
    );

    unless(%OldSettings) {
      return $Self->{LayoutObject}->ErrorScreen(
        Message => Translatable('Could not get System Configuration'),
        Comment => Translatable('Please contact the administrator.'),
      );
    }

    my $NewSettings = {
      ChannelPrefix => $OldSettings{EffectiveValue}->{ChannelPrefix},
      # boolean values should work automatically
    };

    # text fields
    if(IsStringWithData($Form{ChannelPrefix}) &&
      $Form{ChannelPrefix} =~ /^[0-9a-zA-Z-_.]+$/) {
      $NewSettings->{ChannelPrefix} = $Form{ChannelPrefix};
    } else {
      $Error = '&Error=ChannelPrefixError';
    }

    # selections
    $NewSettings->{UserDiscoveryType} = $Form{UserDiscoveryType};

    # boolean selections work like checkboxes
    $NewSettings->{InviteUsers} = exists $Form{InviteUsers};

    # checkboxes
    $NewSettings->{IncludeArticleEmails} = exists $Form{IncludeArticleEmails};
    $NewSettings->{IncludeCcEmails} = exists $Form{IncludeCcEmails};
    $NewSettings->{IncludeHiddenEmails} = exists $Form{IncludeHiddenEmails};
    $NewSettings->{DynamicTicketMenu} = exists $Form{DynamicTicketMenu};

    my $UpdateResult = $Self->{Sysconfig}->SettingsSet(
      UserID => $Self->{UserID},
      Comments => 'Update Rocket.Chat General Config via AdminRocketChat',
      Settings => [
        {
          Name => GENERAL_CONFIG,
          IsValid => exists $Form{Enable},
          EffectiveValue => $NewSettings,
        },
      ],
    );

    unless($UpdateResult) {
      return $Self->{LayoutObject}->ErrorScreen(
        Summary => Translatable('Could not update System Configuration'),
        Comment => Translatable('Please contact the administrator.'),
      );
    }

    return $Self->{LayoutObject}->Redirect(
      OP => 'Action=AdminRocketChat' . $Error,
    );
  } elsif($Self->{Subaction} eq 'DeleteWebserviceAction') {
    # Check for Submit param to be sure it was sent by the form
    my $Submit = $Self->{ParamObject}->GetParam(Param => 'Submit');

    unless($Submit eq 'Delete') {
      return $Self->{LayoutObject}->ErrorScreen(
        Message => Translatable('Delete Request invalid'),
      );
    }

    # Get Webservice
    my $Webservice = $Self->{WebserviceObject}->WebserviceGet(
      ID => $WebserviceConfig{EffectiveValue}->{WebserviceID},
    );

    # Logout and delete the webservice if it exists
    if(IsHashRefWithData($Webservice)) {
      # ignore logout result
      my $LogoutResult = $Self->{RequesterObject}->Run(
        WebserviceID => $WebserviceConfig{EffectiveValue}->{WebserviceID},
        Invoker => 'Logout',
        Asyncronous => 0,
        Data => {},
      );

      my $DeleteResult = $Self->{WebserviceObject}->WebserviceDelete(
        ID => $WebserviceConfig{EffectiveValue}->{WebserviceID},
        UserID => $Self->{UserID},
      );

      unless($DeleteResult) {
        return $Self->{LayoutObject}->ErrorScreen(
          Message => Translatable('Unable to delete the Webservice'),
        );
      }
    }

    # Remove WebserviceID from Config
    my $SysconfigResult = $Self->{Sysconfig}->SettingsSet(
      UserID => $Self->{UserID},
      Comments => 'Remove deleted Webservice',
      Settings => [
        {
          Name => WEBSERVICE_CONFIG,
          IsValid => 0,
          EffectiveValue => {},
        },
      ],
    );

    unless($SysconfigResult) {
      return $Self->{LayoutObject}->ErrorScreen(
        Summary => Translatable('Could not update System Configuration'),
        Comment => Translatable('Please contact the administrator.'),
      );
    }

    # Redirect to default subaction
    return $Self->{LayoutObject}->Redirect(OP => "Action=AdminRocketChat");
  } elsif($Self->{Subaction} eq 'SetupWebserviceAction') {
    if(IsNumber($WebserviceConfig{EffectiveValue}->{WebserviceID})) {
      return $Self->{LayoutObject}->ErrorScreen(
        Message => Translatable('Can\'t setup Webservice'),
        Comment => Translatable('Webservice already exists'),
      );
    }

    my %Form;

    # check for required params and exit with error if one is missing
    for my $Name (qw(BaseUrl APIUrl Username Password)) {
      my $p = $Self->{ParamObject}->GetParam(Param => $Name);
      if($p) {
        $Form{$Name} = $p;
      } else {
        return $Self->{LayoutObject}->ErrorScreen(
          Message => $Self->{LayoutObject}->{LanguageObject}
            ->Translate('Missing parameter %s. Did you specify it?', $Name),
        );
      }
    }

    # TODO validate form inputs

    # Create a title with indication when it was generated
    my $DateTimeObject = $Kernel::OM->Create('Kernel::System::DateTime');
    my $WebserviceName = $DateTimeObject->Format(
      Format => 'Rocket.Chat (automatically created at %Y-%m-%d %H:%M:%S)'
    );

    # First we create a initial Webservice configuration without authentication
    # information. This is then used to send a request to the login endpoint
    # to obtain the User ID and Auth Token we require for all further requests.
    my $InitialConfig = {
      # RemoteSystem is a general data field OTOBO doesn't process (only stores it)
      # We use it to save the base url of the Rocket.Chat installation
      RemoteSystem => $Form{BaseUrl},
      Description => 'Webservice used by OTOBO Rocket.Chat module to communicate with the Rocket.Chat server',
      Requester => {
        Invoker => {
          Lookup => {
            Description => 'Finds all Rocket.Chat usernames corresponding to a given list of email addresses',
            Type => 'RocketChat::Lookup',
          },
          RoomExists => {
            Description => 'Checks wether a room (channel or group) of a given name exists',
            Type => 'RocketChat::RoomExists',
          },
          GroupCreate => {
            Description => 'Creates a Rocket.Chat private group with a given list of members',
            Type => 'RocketChat::GroupCreate',
          },
          GroupAddOwner => {
            Description => 'Makes an user of a given id channel owner',
            Type => 'RocketChat::GroupAddOwner',
          },
          GroupInvite => {
            Description => 'Invites an user to a group',
            Type => 'RocketChat::GroupInvite',
          },
          GroupMemberOf => {
            Description => 'Checks wether the Rocket.Chat user is member of a group with a given name',
            Type => 'RocketChat::GroupMemberOf',
          },
          GroupMembers => {
            Description => 'Returns the list of members of a given group',
            Type => 'RocketChat::GroupMembers',
          },
          GroupSetAnnouncement => {
            Description => 'Sets the announcement of a group',
            Type => 'RocketChat::GroupSetAnnouncement',
          },
          Login => {
            Description => 'Obtains auth token and user id for a given username and password',
            Type => 'RocketChat::Login',
          },
          Logout => {
            Description => 'Invalidates used auth token and user id',
            Type => 'RocketChat::Logout',
          },
          UserInfo => {
            Description => 'Retrieves Information about a Rocket.Chat user',
            Type => 'RocketChat::UserInfo',
          },
        },
        Transport => {
          Type => 'HTTP::REST',
          Config => {
            # This is promoted to at least 30s by OTOBO,
            # seems like we can't do much here.
            Timeout => '5',
            Host => $Form{APIUrl},
            DefaultCommand => 'GET',
            InvokerControllerMapping => {
              Lookup => {
                Command => 'GET',
                Controller => '/users.list',
              },
              RoomExists => {
                Command => 'GET',
                Controller => '/rooms.adminRooms',
              },
              GroupCreate => {
                Command => 'POST',
                Controller => '/groups.create',
              },
              GroupAddOwner => {
                Command => 'POST',
                Controller => '/groups.addOwner',
              },
              GroupInvite => {
                Command => 'POST',
                Controller => '/groups.invite',
              },
              GroupMemberOf => {
                Command => 'GET',
                Controller => '/groups.list',
              },
              GroupMembers => {
                Command => 'GET',
                Controller => '/groups.members',
              },
              GroupSetAnnouncement => {
                Command => 'POST',
                Controller => '/groups.setAnnouncement',
              },
              Login => {
                Command => 'POST',
                Controller => '/login',
              },
              Logout => {
                Command => 'POST',
                Controller => '/logout',
              },
              UserInfo => {
                Command => 'GET',
                Controller => '/users.info',
              },
            },
          },
        },
      },
      Debugger => {
        DebugThreshold => 'error',
      },
    };

    my $WebserviceID = $Self->{WebserviceObject}->WebserviceAdd(
      Name => $WebserviceName,
      Config => $InitialConfig,
      ValidID => 1,
      UserID => $Self->{UserID},
    );

    unless(defined $WebserviceID) {
      return $Self->{LayoutObject}->ErrorScreen(
        Summary => Translatable('Could not create Webservice'),
        Comment => Translatable('Please contact the administrator.'),
      );
    }

    # Set Webservice ID in system config without activating the setting
    # This means the module will stay inactive, but the user will be
    # able to delete the webservice
    my $SysconfigResult = $Self->{Sysconfig}->SettingsSet(
      UserID => $Self->{UserID},
      Comments => 'Preliminarily add Rocket.Chat WebserviceID (not yet set up)',
      Settings => [
        {
          Name => WEBSERVICE_CONFIG,
          IsValid => 0,
          EffectiveValue => {
            WebserviceID => $WebserviceID,
          },
        },
      ],
    );

    unless($SysconfigResult) {
      # try to delete webservice, since
      # we otherwise have no way of remembering
      # which ID it has
      $Self->{WebserviceObject}->WebserviceDelete(
        ID => $WebserviceID,
        UserID => $Self->{UserID},
      );

      return $Self->{LayoutObject}->ErrorScreen(
        Summary => Translatable('Could not update System Configuration'),
        Comment => Translatable('Please contact the administrator.'),
      );
    }

    # obtain user id and auth token
    my $AuthResult = $Self->{RequesterObject}->Run(
      WebserviceID => $WebserviceID,
      Invoker => 'Login',
      Asyncronous => 0,
      Data => {
        Username => $Form{Username},
        Password => $Form{Password},
      },
    );

    unless($AuthResult->{Success}) {
      return $Self->_WebserviceError(
        Error => 'AuthError',
        WebserviceID => $WebserviceID,
        Subaction => 'SetupWebservice',
      );
    }

    # Now we have obtained the user id and auth token and can update the
    # webservice config to include authentication information.
    # Note that AdditionalHeaders working in OTOBO is a feature that needs to be
    # patched in: https://github.com/sternenseemann/otrs/commit/123bf835131f689370749ea0bab5666022d273df
    $InitialConfig->{Requester}->{Transport}->{Config}->{AdditionalHeaders} = {
      'X-Auth-Token' => $AuthResult->{Data}->{AuthToken},
      'X-User-Id' => $AuthResult->{Data}->{UserID},
    };

    my $UpdateResult = $Self->{WebserviceObject}->WebserviceUpdate(
      ID => $WebserviceID,
      Name => $WebserviceName,
      Config => $InitialConfig,
      ValidID => 1,
      UserID => $Self->{UserID},
    );

    unless($UpdateResult) {
      return $Self->_WebserviceError(
        Error => 'UpdateError',
        WebserviceID => $WebserviceID,
        Subaction => 'SetupWebservice',
      );
    }

    # Finally save the WebserviceID in system config
    $SysconfigResult = $Self->{Sysconfig}->SettingsSet(
      UserID => $Self->{UserID},
      Comments => 'Make Rocket.Chat WebserviceID setting valid (fully set up)',
      Settings => [
        {
          Name => WEBSERVICE_CONFIG,
          IsValid => 1,
          EffectiveValue => {
            WebserviceID => $WebserviceID,
          },
        },
      ],
    );

    unless($SysconfigResult) {
      return $Self->_WebserviceError(
        Error => 'UpdateError',
        WebserviceID => $WebserviceID,
        Subaction => 'SetupWebservice',
      );
    }

    # Redirect to default subaction
    return $Self->{LayoutObject}->Redirect(OP => "Action=AdminRocketChat");
  } elsif($Self->{Subaction} eq 'SetupWebservice') {
    # Link back
    $Self->{LayoutObject}->Block(
      Name => 'ActionChange',
    );

    $Self->{LayoutObject}->Block(
      Name => 'SetupWebservice',
    );

    if(IsNumber($WebserviceConfig{EffectiveValue}->{WebserviceID})) {
      # Webservice exists, show hint to delete it and delete action
      $Self->{LayoutObject}->Block(
        Name => 'SetupWebserviceExists',
      );

      $Self->{LayoutObject}->Block(
        Name => 'ActionDeleteWebservice',
      );
    } else {
      $Self->{LayoutObject}->Block(
        Name => 'SetupWebserviceForm',
      );
    }
  } elsif($Self->{Subaction} eq 'DeleteWebservice') {
      # Link back
      $Self->{LayoutObject}->Block(
        Name => 'ActionChange',
      );

      $Self->{LayoutObject}->Block(
        Name => 'DeleteWebservice',
      );

      if(IsNumber($WebserviceConfig{EffectiveValue}->{WebserviceID})) {
        # Webservice exists, show confirmation screen
        $Self->{LayoutObject}->Block(
          Name => 'DeleteWebserviceForm',
        );
      } else {
        # Doesn't exist, show notice and link back
        $Self->{LayoutObject}->Block(
          Name => 'ActionSetupWebservice',
        );

        $Self->{LayoutObject}->Block(
          Name => 'DeleteWebserviceDoesntExist',
        );
      }
  } else {
    # default action (change)
    $Self->{LayoutObject}->Block(
      Name => 'Change',
    );

    if(IsNumber($WebserviceConfig{EffectiveValue}->{WebserviceID})) {
      # webservice exists, show config form

      my %GeneralConfig = $Self->{Sysconfig}->SettingGet(
        Name => GENERAL_CONFIG,
      );

      $Self->{LayoutObject}->Block(
        Name => 'ActionDeleteWebservice',
      );

      # get selectable options for user discovery type from config
      my $GeneralConfigHash = $GeneralConfig{XMLContentParsed}->{Value}->[0]->{Hash}->[0]->{Item};

      my @SelectionOptions = ();

      for my $ConfigEntry (@{$GeneralConfigHash}) {
        if($ConfigEntry->{Key} eq 'UserDiscoveryType') {
          for my $Option (@{$ConfigEntry->{Item}}) {
            my $Ref = {
              Key => $Option->{Value},
              Value => $Option->{Content},
            };

            if($GeneralConfig{EffectiveValue}->{UserDiscoveryType} eq $Option->{Value}) {
              $Ref->{Selected} = 1;
            }

            push @SelectionOptions, $Ref;
          }
        }
      }

      my $UserDiscoverySelection = $Self->{LayoutObject}->BuildSelection(
        Data => \@SelectionOptions,
        Name => 'UserDiscoveryType',
        ID => 'UserDiscoveryType',
        Class => 'Modernize W25pc',
      );

      my $InviteUsersOptions = [
        {
          Key => 1,
          Value => $Self->{LayoutObject}->{LanguageObject}
            ->Translate('Invite to channel'),
          Selected => $GeneralConfig{EffectiveValue}->{InviteUsers},
        },
        {
          Key => 0,
          Value => $Self->{LayoutObject}->{LanguageObject}
            ->Translate('Add directly to channel'),
          Selected => !$GeneralConfig{EffectiveValue}->{InviteUsers},
        },
      ];

      my $InviteUsersSelection = $Self->{LayoutObject}->BuildSelection(
        Data => $InviteUsersOptions,
        Name => 'InviteUsers',
        ID => 'InviteUsers',
        Class => 'Modernize W25pc',
      );

      $Self->{LayoutObject}->Block(
        Name => 'ChangeForm',
        Data => {
          Enable => $GeneralConfig{IsValid},
          Active => IsExtensionActive(SysConfigObject => $Self->{Sysconfig}),
          WebserviceID => $WebserviceConfig{EffectiveValue}->{WebserviceID},
          ChannelPrefix => $GeneralConfig{EffectiveValue}->{ChannelPrefix},
          UserDiscoverySelection => $UserDiscoverySelection,
          InviteUsersSelection => $InviteUsersSelection,
          IncludeArticleEmails => $GeneralConfig{EffectiveValue}->{IncludeArticleEmails},
          IncludeHiddenEmails => $GeneralConfig{EffectiveValue}->{IncludeHiddenEmails},
          IncludeCcEmails => $GeneralConfig{EffectiveValue}->{IncludeCcEmails},
          DynamicTicketMenu => $GeneralConfig{EffectiveValue}->{DynamicTicketMenu},
        },
      );
    } else {
      # doesn't exist, tell user to create one
      $Self->{LayoutObject}->Block(
        Name => 'ActionSetupWebservice',
      );

      $Self->{LayoutObject}->Block(
        Name => 'ChangeRequireSetup',
      );
    }
  }

  $Output .= $Self->{LayoutObject}->Output(
    TemplateFile => 'AdminRocketChat',
    Data => {
      Subaction => $Self->{Subaction},
    },
  );

  $Output .= $Self->{LayoutObject}->Footer();

  return $Output;
}

sub _WebserviceError {
  my ($Self, %Param) = @_;

  unless($Param{WebserviceID}) {
    return;
  }

  unless($Param{Error}) {
    return;
  }

  my $DeleteResult = $Self->{WebserviceObject}->WebserviceDelete(
    ID => $Param{WebserviceID},
    UserID => $Self->{UserID},
  );

  my $SysConfigResult = $Self->{Sysconfig}->SettingsSet(
        UserID => $Self->{UserID},
        Comments => 'Make Rocket.Chat WebserviceID setting valid (fully set up)',
        Settings => [
          {
            Name => WEBSERVICE_CONFIG,
            IsValid => 0,
            EffectiveValue => {},
          },
        ],
      );

  if($DeleteResult && $SysConfigResult) {
    my $Subaction;
    if($Param{Subaction}) {
      $Subaction = "&Subaction=" . $Param{Subaction};
    } else {
      $Subaction = "";
    }

    return $Self->{LayoutObject}->Redirect(
      OP => "Action=AdminRocketChat" . $Subaction . "&Error=" . $Param{Error}
    );
  } else {
    return $Self->{LayoutObject}->ErrorScreen(
      Summary => Translatable('Could not clean up error ' . $Param{Error}),
      Comment => Translatable('Please contact the administrator.'),
    );
  }
}

1;
