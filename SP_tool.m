function SP_tool(varargin)
% Function to create a Save Preferences button as part of the MR_toolbox
% kit. Allows for certain widget settings to be changed permanently.
%
if isempty(varargin)
    Action = 'New';
else
    Action = varargin{1};
end

switch Action,
    case  'New',                 Create_New_Objects;
    case 'Save',                 Save_Prefs;
    otherwise
        disp(['Unimplemented Functionality: ', Action]);
        
end;
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%%
function Create_New_Objects
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
dispDebug;

hUtils = MR_Toolbox_Utilities;

hFig = gcf;

objNames = retrieveNames;

%Create Button
hButton = hUtils.createButtonObject(hFig, ...
    makeButtonImage, ...
    [],...
    [],...
    objNames.buttonTag, ...
    objNames.buttonToolTipString);

if ~isempty(hButton)

    hButton.ClickedCallback = 'SP_tool(''Save'')';
    hButton.Enable = 'off';
    hButton.UserData = [];

    aD.hUtils    =  hUtils;
    aD.hRoot     = groot;
    aD.hFig      = hFig;
    aD.hButton   = hButton;
    
    storeAD(aD);
end
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%%
function Save_Prefs
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Input a pairing of object names and properties that can be saved through
% "Save Preference" tool. These are contained the button's Userdata which
% is filled by each individual tool upon opening (pressing) of the button.
dispDebug;

aD = getAD;

% Retrive info loaded during Activate_ function of a tool
udata = aD.hButton.UserData;
hCurrToolFig = udata{1};
figFilename = udata{2};
optionalUIControls = udata{3};

%hTemplateToolFig  = openfig(figFilename, 'invisible');
hTemplateToolFig  = openfig(figFilename);

%handlesTemplate = guihandles(hTemplateToolFig);
handlesCurrent  = guihandles(hCurrToolFig);

%For each "child" object member of the GUI
for i=1:length(hTemplateToolFig.Children),
    if ~isempty(hTemplateToolFig.Children(i).Tag)
        % For each GUI control that is listed as 'storable'
        for j=1:size(optionalUIControls,1),
            if strcmpi( hTemplateToolFig.Children(i).Tag, optionalUIControls{j,1}),
                %disp('Found a matching control object')
                hTemplateToolFig.Children(i).(optionalUIControls{j,2}) = ....
                handlesCurrent.(optionalUIControls{j,1}).(optionalUIControls{j,2});
            end;
        end;
    end;
end;

hTemplateToolFig.Visible = 'on';
savefig(hTemplateToolFig, figFilename)

close(hTemplateToolFig);
aD.hButton.State = 'Off';
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%START SUPPORT FUNCTIONS%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%%
%
function structNames = retrieveNames
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
structNames.toolName            = 'PZ_tool';
structNames.buttonTag           = 'figSavePrefsTool';
structNames.buttonToolTipString = 'Save Preferences Tool';
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%%
%
function buttonImage = makeButtonImage
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
% The default button size is 15 x 16 x 3.
dispDebug;

buttonSize_x= 16;
buttonImage = NaN* zeros(15,buttonSize_x);

f = [ ...
    50    51    52    53    54    55    56    57    65    68 ...
    72    80    84    87    95    100   102   110   116   117 ...
    125   130   132   140   144   147   155   156   157   158 ...
    159   160   161   162   172   186   200   214   228 ...
    ];

buttonImage(f) = 0;
buttonImage = repmat(buttonImage, [1,1,3]);
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%%
%
function  dispDebug(varargin)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Print a debug string if global debug flag is set
global DB;

if DB
    objectNames = retrieveNames;
    x = dbstack;
    func_name = x(2).name;    loc = [];
    if length(x) > 3
        loc = [' (loc) ', repmat('|> ',1, length(x)-3)] ;
    end
    fprintf([objectNames.toolName, ':',loc , ' %s'], func_name);
    if nargin>0
        for i = 1:length(varargin)
            str = varargin{i};
            fprintf(': %s', str);
        end
    end
    fprintf('\n');
    
end
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%%
%
function  storeAD(aD)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
dispDebug;
setappdata(aD.hFig, 'SPData', aD);
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%%%%%%%%%%%%%%%%%%%%%%%
%
function  aD = getAD
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
dispDebug;

% fastest way to find figure; doesn't work during Create
tic
aD = [];
hFig = findobj(groot, 'Tag', 'ActiveFigure'); %flat?

if isempty(hFig)
    % Call from Activate
    objNames = retrieveNames;
    obj = findobj('Tag', objNames.buttonTag);
    if ~isempty(obj)
        while ~strcmpi(obj.Type, 'Figure')
            obj = obj.Parent;
        end
        hFig = obj;
    end
end

if isappdata(hFig, 'SPData')
    aD = getappdata(hFig, 'SPData');
end
    
dispDebug(['end (',num2str(toc),')']);
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
