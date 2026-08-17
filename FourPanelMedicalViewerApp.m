classdef FourPanelMedicalViewerApp < matlab.apps.App
    %FOURPANELMEDICALVIEWERAPP Interactive app for viewing medical volumes
    %   This app provides a complete interface for medical imaging
    %   visualization with import capabilities and time-series controls.
    %   
    %   Copyright 2026 The MathWorks, Inc.

    % Used to locate and load the app's XML configuration file
    properties (Access = public, Constant)
        AppConfigFilename = './FourPanelMedicalViewerApp.xml'; % File path to the app configuration file containing component layout and settings
    end

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                        matlab.ui.Figure
        ImportMenu                      matlab.ui.container.Menu
        FromFileMenu                    matlab.ui.container.Menu
        FromFolderMenu                  matlab.ui.container.Menu
        FromPACSServerMenu              matlab.ui.container.Menu
        MainGridLayout                  matlab.ui.container.GridLayout
        ToolstripGridLayout             matlab.ui.container.GridLayout
        TimeSeriesGrid                  matlab.ui.container.GridLayout
        FrameCounterLabel               matlab.ui.control.Label
        TimeFrameSlider                 matlab.ui.control.Slider
        NextFrameButton                 matlab.ui.control.Button
        PlayButton                      matlab.ui.control.StateButton
        PreviousFrameButton             matlab.ui.control.Button
        TimeSeriesBrowserLabel          matlab.ui.control.Label
        RenderingStyleDropDown          matlab.ui.control.DropDown
        RenderingStyleLabel             matlab.ui.control.Label
        CrosshairButton                 matlab.ui.control.StateButton
    end

    
    properties (Access = private)
        MedicalViewerComponent FourPanelMedicalViewer
        % PACS Dialog
        PACSDialog             PACSConnectionApp       

        % Animation control
        IsPlaying              logical = false
        AnimationTimer         timer

        % onCleanup to guarantee timer deletion
        TimerCleanupObj        
    end
    
    methods (Access = private)
        
        function onPACSImportCompleted(app, pacsDialog)
            % ONPACSIMPORTCOMPLETED Handle successful PACS data import

            % Get the downloaded filepath from PACS dialog
            downloadedPath = pacsDialog.Filepath;

            if isempty(downloadedPath)
                uialert(app.UIFigure, ...
                    "No data was downloaded from PACS server", ...
                    "Import Failed");
                return;
            end

            % Hide PACS dialog
            pacsDialog.Visible = "off";

            try
                % Load the medical volume and set it to the viewer component
                volumeData = medicalVolume(downloadedPath);
                app.MedicalViewerComponent.Volume = volumeData;

                % Update time-series controls based on loaded volume
                updateTimeSeriesControls(app);

            catch ME
                % Show error message
                uialert(app.UIFigure, ...
                    "Failed to load volume from PACS data:"+newline+string(ME.message), ...
                    "Import Error", ...
                    "Icon", "error");
            end
        end

        function updateTimeSeriesControls(app)
            % UPDATETIMESERIESCONTROLS Update time-series controls based on volume

            % Stop animation if playing
            if app.IsPlaying
                stopAnimation(app);
            end

            if isTimeSeriesVolume(app.MedicalViewerComponent)
                enableTimeSeriesControls(app, true);
            else
                enableTimeSeriesControls(app, false);
            end
        end

        function enableTimeSeriesControls(app, enableFlag)
            % ENABLETIMESERIESCONTROLS Enable/disable time-series playback controls

            if enableFlag
                numTimeFrames = getNumberOfTimeFrames(app.MedicalViewerComponent);
                controlState = "on";
                app.TimeFrameSlider.Limits = [1 numTimeFrames];
                app.TimeFrameSlider.Value = 1;
                app.FrameCounterLabel.Text = "1/"+num2str(numTimeFrames);
            else
                controlState = "off";
                app.TimeFrameSlider.Value = 1;
                app.FrameCounterLabel.Text = '';
            end

            app.PreviousFrameButton.Enable = controlState;
            app.PlayButton.Enable = controlState;
            app.NextFrameButton.Enable = controlState;
            app.TimeFrameSlider.Enable = controlState;
            app.TimeSeriesBrowserLabel.Enable = controlState;
        end

        function startAnimation(app)
            % STARTANIMATION Start playing through time frames

            app.IsPlaying = true;

            % Disable other navigation controls during playback
            app.PreviousFrameButton.Enable = "off";
            app.NextFrameButton.Enable = "off";
            app.TimeFrameSlider.Enable = "off";

            % Create and start timer for animation
            if isempty(app.AnimationTimer) || ~isvalid(app.AnimationTimer)
                app.AnimationTimer = timer(...
                    "Name", "FourPanelMedicalViewerAppAnimationTimer",...
                    "ExecutionMode", "fixedRate", ...
                    "Period", 0.1, ...
                    "TimerFcn", @(~,~) advanceFrame(app));
            end
            start(app.AnimationTimer);
        end

        function stopAnimation(app)
            % STOPANIMATION Stop playing through time frames

            app.IsPlaying = false;
            app.PlayButton.Value = false;

            % Re-enable navigation controls
            app.PreviousFrameButton.Enable = "on";
            app.NextFrameButton.Enable = "on";
            app.TimeFrameSlider.Enable = "on";

            % Stop and delete timer
            if ~isempty(app.AnimationTimer) && isvalid(app.AnimationTimer)
                stop(app.AnimationTimer);
            end
        end

        function advanceFrame(app)
            % ADVANCEFRAME Move to next frame during animation playback
            onNextFrameButtonPushed(app);
        end

        
        function cleanupTimer(app)                                                                                                                                                 
            animationTimer = timerfind("Name", "FourPanelMedicalViewerAppAnimationTimer");                                                                                                                                      
            if ~isempty(animationTimer)                                                                                                                                                         
                stop(animationTimer);                                                                                                                                                           
                delete(animationTimer);                                                                                                                                                         
            end                                                                                                                                                                   
        end
    end
    

    % Callbacks that handle component events
    methods

        % Code that executes after component creation
        function startupFcn(app)
            app.MedicalViewerComponent = FourPanelMedicalViewer(app.MainGridLayout);
            if app.CrosshairButton.Value
                app.MedicalViewerComponent.Crosshair = "on";
            else
                app.MedicalViewerComponent.Crosshair = "off";
            end

            % Guarantee timer cleanup regardless of how app is destroyed                                                                                                           
            app.TimerCleanupObj = onCleanup(@() cleanupTimer(app));
        end

        % Close request function: UIFigure
        function closeApp(app, event)
            % CLOSEAPP Clean up and close the application

            % Stop animation and clean up timer
            if app.IsPlaying
                stopAnimation(app);
            end
            if ~isempty(app.AnimationTimer) && isvalid(app.AnimationTimer)
                stop(app.AnimationTimer);
                delete(app.AnimationTimer);
            end

            % Clean up PACS dialog
            if ~isempty(app.PACSDialog) && isvalid(app.PACSDialog)
                delete(app.PACSDialog);
            end

            % Delete the UI figure
            delete(app.UIFigure);
            
        end

        % Menu selected function: FromFileMenu
        function loadVolumeFromFile(app, event)
            % LOADVOLUMEFROMFILE Load medical volume from a single file
            [fileName, filePath] = uigetfile(...
                ["*.dcm;*.dcs;*.dic;*.ima;*.nii;*.nii.gz;*.nrrd;*.nhdr", "Medical Image Files (*.dcm, *.nii, *.nrrd)"], ...
                "Select Medical Volume File");

            if isequal(fileName, 0)
                return; % User cancelled
            end

            fullFilePath = fullfile(filePath, fileName);
            try
                volumeData = medicalVolume(fullFilePath);
                app.MedicalViewerComponent.Volume = volumeData;

                % Update time-series controls based on loaded volume
                updateTimeSeriesControls(app);

            catch ME
                uialert(app.UIFigure, ME.message, "File Load Error");
            end
        end

        % Menu selected function: FromFolderMenu
        function loadVolumeFromFolder(app, event)
            % LOADVOLUMEFROMFOLDER Load medical volume from DICOM folder
            folderPath = uigetdir('', "Select Folder Containing DICOM Files");

            if isequal(folderPath, 0)
                return; % User cancelled
            end

            try
                volumeData = medicalVolume(folderPath);
                app.MedicalViewerComponent.Volume = volumeData;

                % Update time-series controls based on loaded volume
                updateTimeSeriesControls(app);

            catch ME
                uialert(app.UIFigure, ME.message, "Folder Load Error");
            end
        end

        % Menu selected function: FromPACSServerMenu
        function loadVolumeFromPACS(app, event)
            % LOADVOLUMEFROMPACS Open PACS dialog for importing medical volumes

            if isempty(app.PACSDialog) || ~isvalid(app.PACSDialog)
                % Create new PACS dialog configured for app integration
                app.PACSDialog = PACSConnectionApp(true);

                % Listen for successful import events
                addlistener(app.PACSDialog, "ImportIsSuccessful", ...
                    @(src, evt) onPACSImportCompleted(app, src));
            end

            % Show the PACS dialog
            app.PACSDialog.Visible = "on";
        end

        % Value changed function: CrosshairButton
        function onCrosshairButtonValueChanged(app, event)
            % ONCROSSHAIRBUTTONVALUECHANGED Toggle crosshair display
            if ~isempty(app.MedicalViewerComponent) && isvalid(app.MedicalViewerComponent)
                if app.CrosshairButton.Value
                    app.MedicalViewerComponent.Crosshair = "on";
                else
                    app.MedicalViewerComponent.Crosshair = "off";
                end
            end
            
        end

        % Value changed function: RenderingStyleDropDown
        function onRenderingStyleChanged(app, event)
            % RENDERINGSTYLECHANGED Update 3D rendering style
            selectedStyle = app.RenderingStyleDropDown.Value;
            app.MedicalViewerComponent.RenderingStyle = selectedStyle;
            
        end

        % Button pushed function: PreviousFrameButton
        function onPreviousFrameButtonPushed(app, event)
            % PREVIOUSFRAMEBUTTONPUSHED Navigate to previous time frame
            currentFrame = app.MedicalViewerComponent.TimeFrameIndex - 1;
            numTimeFrames = getNumberOfTimeFrames(app.MedicalViewerComponent);

            % Wrap around to last frame if at beginning
            if currentFrame < 1
                currentFrame = numTimeFrames;
            end

            app.MedicalViewerComponent.TimeFrameIndex = currentFrame;
            app.TimeFrameSlider.Value = currentFrame;
            app.FrameCounterLabel.Text = num2str(currentFrame)+"/"+num2str(numTimeFrames);
        end

        % Value changed function: PlayButton
        function onPlayButtonPushed(app, event)
            % ONPLAYBUTTONPUSHED Toggle animation playback of 4D time-series

            if app.IsPlaying
                % Stop animation
                stopAnimation(app);
            else
                % Start animation
                startAnimation(app);
            end
            
        end

        % Button pushed function: NextFrameButton
        function onNextFrameButtonPushed(app, event)
            % ONNEXTFRAMEBUTTONPUSHED Navigate to next time frame
            currentFrame = app.MedicalViewerComponent.TimeFrameIndex + 1;
            numTimeFrames = getNumberOfTimeFrames(app.MedicalViewerComponent);

            % Wrap around to first frame if at end
            if currentFrame > numTimeFrames
                currentFrame = 1;
            end

            app.MedicalViewerComponent.TimeFrameIndex = currentFrame;
            app.TimeFrameSlider.Value = currentFrame;
            app.FrameCounterLabel.Text = num2str(currentFrame)+"/"+num2str(numTimeFrames);
        end

        % Callback function: TimeFrameSlider, TimeFrameSlider
        function onTimeFrameSliderChanged(app, event)
            % ONTIMEFRAMESLIDERCHANGED Handle slider value changes
            numTimeFrames = getNumberOfTimeFrames(app.MedicalViewerComponent);
            roundedValue = round(event.Value);

            app.MedicalViewerComponent.TimeFrameIndex = roundedValue;
            app.TimeFrameSlider.Value = roundedValue;
            app.FrameCounterLabel.Text = num2str(roundedValue)+"/"+num2str(numTimeFrames);
            
        end
    end

    % App creation
    methods (Access = public)

        % Construct app
        function app = FourPanelMedicalViewerApp(varargin)
            app = app@matlab.apps.App(varargin{:});

            if nargout == 0
                clear app
            end
        end
    end
end