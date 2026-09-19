classdef ScreeningApp < handle
    %SCREENINGAPP App Designer-compatible integrated retinal screening demo.
    %   app = ScreeningApp creates the modern DocuVerse-inspired clinical
    %   screening UI. All inference logic stays in app.runScreeningCase and
    %   report.generate; this class owns presentation only.
    %
    %   Design Features:
    %     - Clean modern medical dashboard layout (DocuVerse-inspired)
    %     - Left navigation rail with logo, menu items, and operator card
    %     - Top action bar with search field, badges, and emerald action button
    %     - 4 top-level KPI metric cards with clear typography
    %     - 2x2 large square fundus image viewports with 1:1 aspect ratio
    %     - Right clinical insights column for Evidence and ICDR Rule Trace
    %     - Light glassmorphic theme with crisp white cards and fine borders

    properties (Access = public)
        UIFigure
        SelectImageButton
        SampleCaseDropdown
        ResetButton
        ThemeToggleButton
        ImagePathField
        ModelPathField
        CalibrationPathField
        ConfigPathField
        RunButton
        ExportButton
        OriginalAxes
        ProcessedAxes
        GradCAMAxes
        CandidateAxes
        CandidateCaption
        QualityValue
        AdviceValue
        LevelValue
        ProbabilityValue
        DecisionValue
        AgreementValue
        EscalationValue
        EvidenceWarningValue
        EvidenceValue
        RuleTraceArea
        StatusValue
        ProcessingTimeValue
        % Demo-day escape hatch. Set false to skip every reveal animation
        % and have results appear in their final state immediately.
        AnimationsEnabled = true
        % Active theme: 'light' (Glassmorphism, default) or 'dark' (Dark Pro)
        CurrentTheme = 'light'
    end

    properties (Access = private)
        ProjectRoot
        ScreeningResult
        LastReport
        Theme
        CaseNameValue
        DecisionCard
        DecisionGrid
        DecisionCaption
        LevelNameValue
        ProbabilityCaption
        QualityCaption
        StatusDot
        ImageObjects
        PendingReveal
        StageMarks
        StageNames
        SampleCases
        % Stored UI references for theme switching and layout management
        RegisteredCards = {}
        RegisteredLabels = {}
        RootGrid
        SidebarCard
        SidebarGrid
        WorkspaceGrid
        TopBarGrid
        HeaderTitleGrid
        StripGrid
        ContentSplitGrid
        ImagesGrid
        EvidenceColGrid
        OperatingBadge
        SealedBadge
        OverviewTitle
        OverviewSubtitle
        SensitivityLabel
        SpecificityLabel
    end

    methods
        function app = ScreeningApp(varargin)
            app.ProjectRoot = fileparts(fileparts(mfilename('fullpath')));
            addpath(genpath(fullfile(app.ProjectRoot, 'src')));
            app.CurrentTheme = 'light';
            app.Theme = ScreeningApp.palette(app.CurrentTheme);
            app.createComponents();
            app.applyDefaults(varargin{:});
        end

        function showCase(app, imagePath)
            app.ImagePathField.Value = char(imagePath);
            app.refreshCaseName();
            app.runScreening();
        end

        function delete(app)
            if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
                delete(app.UIFigure);
            end
        end

        function setTheme(app, mode)
            if strcmpi(mode, app.CurrentTheme)
                return;
            end
            app.CurrentTheme = lower(mode);
            app.Theme = ScreeningApp.palette(app.CurrentTheme);
            app.applyTheme();
        end

        function toggleTheme(app)
            if strcmpi(app.CurrentTheme, 'light')
                app.setTheme('dark');
            else
                app.setTheme('light');
            end
        end

        function resetApp(app)
            app.ImagePathField.Value = '';
            app.refreshCaseName();
            if ~isempty(app.SampleCaseDropdown) && isvalid(app.SampleCaseDropdown)
                app.SampleCaseDropdown.Value = app.SampleCaseDropdown.ItemsData{1};
            end
            app.clearResultSurfaces();
            app.ExportButton.Enable = 'off';
            t = app.Theme;
            app.ExportButton.FontColor = t.muted;
            app.setStatus('Ready. Select an image or pick a sample case.', t.text, t.muted);
            app.ProcessingTimeValue.Text = 'Processing time  --';
            app.ScreeningResult = [];
            app.LastReport = [];
        end
    end

    methods (Static)
        function t = palette(mode)
            if nargin < 1 || isempty(mode)
                mode = 'light';
            end
            switch lower(mode)
                case 'dark'
                    t.name        = 'dark';
                    t.bg          = [0.055, 0.066, 0.078];
                    t.surface     = [0.086, 0.102, 0.121];
                    t.raised      = [0.125, 0.145, 0.169];
                    t.field       = [0.145, 0.165, 0.192];
                    t.text        = [0.898, 0.914, 0.933];
                    t.muted       = [0.514, 0.557, 0.608];
                    t.faint       = [0.365, 0.404, 0.451];
                    t.accent      = [0.051, 0.647, 0.455];  % DocuVerse emerald
                    t.accentInk   = [1.000, 1.000, 1.000];
                    t.green       = [0.051, 0.647, 0.455];
                    t.amber       = [0.960, 0.647, 0.145];
                    t.red         = [0.945, 0.361, 0.376];
                    t.amberTint   = [0.180, 0.145, 0.075];
                    t.greenTint   = [0.075, 0.180, 0.120];
                    t.redTint     = [0.200, 0.080, 0.090];
                    t.border      = [0.160, 0.185, 0.220];
                    t.axesMatte   = [0.050, 0.060, 0.072];
                otherwise % 'light' (DocuVerse Medical Glassmorphism)
                    t.name        = 'light';
                    t.bg          = [0.948, 0.962, 0.978];  % Soft pearlescent backdrop
                    t.surface     = [1.000, 1.000, 1.000];  % Crisp white cards
                    t.raised      = [0.935, 0.955, 0.980];  % Pill badge & active item background
                    t.field       = [0.965, 0.976, 0.992];  % Input & search background
                    t.text        = [0.070, 0.095, 0.140];  % Modern deep slate typography
                    t.muted       = [0.420, 0.460, 0.520];  % Slate metadata
                    t.faint       = [0.580, 0.620, 0.680];  % Soft captions
                    t.accent      = [0.051, 0.647, 0.455];  % DocuVerse vibrant emerald (#0DA574)
                    t.accentInk   = [1.000, 1.000, 1.000];  % Crisp white on emerald
                    t.green       = [0.051, 0.647, 0.455];  % Success emerald
                    t.amber       = [0.880, 0.480, 0.040];  % Warning warm amber
                    t.red         = [0.880, 0.220, 0.240];  % Danger coral red
                    t.greenTint   = [0.910, 0.975, 0.940];  % Pastel emerald glass tint
                    t.amberTint   = [0.995, 0.955, 0.890];  % Pastel amber glass tint
                    t.redTint     = [0.995, 0.915, 0.925];  % Pastel coral glass tint
                    t.border      = [0.890, 0.915, 0.950];  % Fine crisp border (#E5EBF2)
                    t.axesMatte   = [0.070, 0.085, 0.110];  % High-contrast retina viewfinder
            end
        end
    end

    methods (Access = private)
        function createComponents(app)
            t = app.Theme;

            app.UIFigure = uifigure('Name', ...
                'Retinal Screening Aid  |  SIH26038', ...
                'Position', [30, 30, 1640, 1000], 'Color', t.bg);

            % Root grid: Sidebar (Left) + Main Workspace (Right)
            root = uigridlayout(app.UIFigure, [1, 2]);
            root.ColumnWidth = {270, '1x'};
            root.RowHeight = {'1x'};
            root.Padding = [16, 16, 16, 16];
            root.ColumnSpacing = 16;
            root.BackgroundColor = t.bg;
            app.RootGrid = root;

            app.buildSidebar(root);
            app.buildWorkspace(root);
            app.applyTypography();

            app.UIFigure.KeyPressFcn = @(~, event) app.handleKey(event);
            app.UIFigure.CloseRequestFcn = @(~, ~) delete(app.UIFigure);
            try
                app.UIFigure.WindowState = 'maximized';
            catch
            end
        end

        function applyTypography(app)
            preferred = {'Inter', 'Plus Jakarta Sans', 'Outfit', 'Noto Sans', ...
                'SF Pro Text', 'Roboto', 'Segoe UI', 'DejaVu Sans'};
            installed = listfonts();
            chosen = '';
            for index = 1:numel(preferred)
                if any(strcmpi(installed, preferred{index}))
                    chosen = preferred{index};
                    break;
                end
            end
            if isempty(chosen)
                return;
            end
            components = findall(app.UIFigure);
            for index = 1:numel(components)
                component = components(index);
                if ~isprop(component, 'FontName')
                    continue;
                end
                if strcmpi(get(component, 'FontName'), 'monospace')
                    continue;
                end
                try
                    component.FontName = chosen;
                catch
                end
            end
        end

        function handleKey(app, event)
            if strcmp(event.Key, 'return') && strcmp(app.RunButton.Enable, 'on')
                app.runScreening();
            end
        end

        % ----------------------------------------------------------- sidebar
        function buildSidebar(app, parent)
            t = app.Theme;
            card = uipanel(parent, 'BorderType', 'line', ...
                'BorderColor', t.border, 'BackgroundColor', t.surface);
            card.Layout.Column = 1;
            app.SidebarCard = card;

            grid = uigridlayout(card, [10, 1]);
            grid.RowHeight = {50, 36, 32, 140, 72, 115, 145, '1x', 56, 32};
            grid.ColumnWidth = {'1x'};
            grid.Padding = [16, 16, 16, 16];
            grid.RowSpacing = 10;
            grid.BackgroundColor = t.surface;
            app.SidebarGrid = grid;

            % --- Brand Logo Block (DocuVerse style)
            logoBox = uigridlayout(grid, [1, 2]);
            logoBox.Layout.Row = 1;
            logoBox.ColumnWidth = {34, '1x'};
            logoBox.RowHeight = {'1x'};
            logoBox.Padding = [0, 0, 0, 0];
            logoBox.ColumnSpacing = 8;
            logoBox.BackgroundColor = t.surface;

            logoIcon = uilabel(logoBox, 'Text', '✦', 'FontSize', 22, ...
                'FontColor', t.accent, 'HorizontalAlignment', 'center');
            logoIcon.Layout.Column = 1;

            logoTitle = uilabel(logoBox, 'Text', 'RetinalAI', ...
                'FontSize', 18, 'FontWeight', 'bold', 'FontColor', t.text);
            logoTitle.Layout.Column = 2;

            % --- Active Menu Navigation Item
            navPill = uipanel(grid, 'BorderType', 'none', ...
                'BackgroundColor', t.raised);
            navPill.Layout.Row = 2;
            navGrid = uigridlayout(navPill, [1, 2]);
            navGrid.ColumnWidth = {24, '1x'};
            navGrid.RowHeight = {'1x'};
            navGrid.Padding = [10, 4, 10, 4];
            navGrid.ColumnSpacing = 8;
            navGrid.BackgroundColor = t.raised;
            uilabel(navGrid, 'Text', '▦', 'FontSize', 14, 'FontColor', t.text);
            uilabel(navGrid, 'Text', 'Screening Dashboard', ...
                'FontSize', 12.5, 'FontWeight', 'bold', 'FontColor', t.text);

            % --- Submenu indicator
            app.caption(grid, 3, 'IMAGE INPUT & CASE PRESETS');

            % --- Case Selection Card (inside sidebar)
            caseBox = uigridlayout(grid, [4, 1]);
            caseBox.Layout.Row = 4;
            caseBox.RowHeight = {32, 28, 28, 20};
            caseBox.Padding = [0, 0, 0, 0];
            caseBox.RowSpacing = 8;
            caseBox.BackgroundColor = t.surface;

            app.SelectImageButton = uibutton(caseBox, 'push', ...
                'Text', '📁  Browse Fundus File...', ...
                'FontSize', 11.5, 'FontColor', t.text, ...
                'BackgroundColor', t.field, ...
                'Tooltip', 'Select an image file from your computer', ...
                'ButtonPushedFcn', @(~, ~) app.selectImage());
            app.SelectImageButton.Layout.Row = 1;

            app.buildSampleDropdown(caseBox, 2);

            app.CaseNameValue = uilabel(caseBox, 'Text', 'No image selected', ...
                'FontSize', 10.5, 'FontColor', t.faint, 'WordWrap', 'on');
            app.CaseNameValue.Layout.Row = 3;

            hint = uilabel(caseBox, 'Text', 'Shortcut: Press ↵ Enter to run', ...
                'FontSize', 9.5, 'FontColor', t.faint);
            hint.Layout.Row = 4;

            % --- Status Card
            [~, statusGrid] = app.card(grid, 5, {14, 20, 16});
            app.caption(statusGrid, 1, 'SYSTEM STATUS');
            statusRow = uigridlayout(statusGrid, [1, 2]);
            statusRow.Layout.Row = 2;
            statusRow.ColumnWidth = {10, '1x'};
            statusRow.RowHeight = {'1x'};
            statusRow.Padding = [0, 0, 0, 0];
            statusRow.ColumnSpacing = 6;
            statusRow.BackgroundColor = t.surface;
            app.StatusDot = uilabel(statusRow, 'Text', '●', ...
                'FontSize', 11, 'FontColor', t.muted);
            app.StatusDot.Layout.Column = 1;
            app.StatusValue = uilabel(statusRow, 'Text', 'Ready', ...
                'FontSize', 11.5, 'FontWeight', 'bold', 'FontColor', t.text);
            app.StatusValue.Layout.Column = 2;
            app.ProcessingTimeValue = uilabel(statusGrid, ...
                'Text', 'Processing time  --', ...
                'FontSize', 10, 'FontColor', t.faint);
            app.ProcessingTimeValue.Layout.Row = 3;

            % --- Validation Performance Card
            app.buildPerformanceCard(grid, 6);

            % --- Pipeline stages
            app.buildPipelineCard(grid, 7);

            % --- Operator Profile Card (DocuVerse style)
            userCard = uipanel(grid, 'BorderType', 'line', ...
                'BorderColor', t.border, 'BackgroundColor', t.field);
            userCard.Layout.Row = 9;
            userGrid = uigridlayout(userCard, [1, 2]);
            userGrid.ColumnWidth = {34, '1x'};
            userGrid.RowHeight = {'1x'};
            userGrid.Padding = [8, 8, 8, 8];
            userGrid.ColumnSpacing = 8;
            userGrid.BackgroundColor = t.field;

            avatar = uilabel(userGrid, 'Text', '👤', 'FontSize', 18, ...
                'HorizontalAlignment', 'center');
            avatar.Layout.Column = 1;
            uInfo = uigridlayout(userGrid, [2, 1]);
            uInfo.Layout.Column = 2;
            uInfo.RowHeight = {16, 14};
            uInfo.Padding = [0, 0, 0, 0];
            uInfo.RowSpacing = 2;
            uInfo.BackgroundColor = t.field;
            uilabel(uInfo, 'Text', 'Dr. Operator', 'FontSize', 11, ...
                'FontWeight', 'bold', 'FontColor', t.text);
            uilabel(uInfo, 'Text', 'Clinician  ·  ID: #726302', ...
                'FontSize', 9.5, 'FontColor', t.faint);

            % --- Disclaimer
            footer = uilabel(grid, 'Text', ...
                'Screening Aid & Research Prototype.', ...
                'FontSize', 9.5, 'FontColor', t.faint, ...
                'HorizontalAlignment', 'center');
            footer.Layout.Row = 10;
        end

        function buildSampleDropdown(app, parent, row)
            t = app.Theme;
            app.SampleCases = { ...
                '-- Quick Select Preset --', ''; ...
                'Sample 1: No DR (Grade 0)', 'data/raw/aptos2019/train_images/0097f532ac9f.png'; ...
                'Sample 2: Mild NPDR (Grade 1)', 'data/raw/aptos2019/train_images/0024cdab0c1e.png'; ...
                'Sample 3: Moderate NPDR (Grade 2)', 'data/raw/aptos2019/train_images/000c1434d8d7.png'; ...
                'Sample 4: Severe PDR (Grade 4)', 'data/raw/aptos2019/train_images/03a7f4a5786f.png' ...
            };

            app.SampleCaseDropdown = uidropdown(parent, ...
                'Items', app.SampleCases(:, 1), ...
                'ItemsData', app.SampleCases(:, 2), ...
                'Value', '', ...
                'FontSize', 10.5, ...
                'FontColor', t.text, ...
                'BackgroundColor', t.field, ...
                'Tooltip', 'Quick load a committed validation sample case', ...
                'ValueChangedFcn', @(~, event) app.handleSampleSelected(event));
            app.SampleCaseDropdown.Layout.Row = row;
        end

        function handleSampleSelected(app, event)
            selectedRelPath = event.Value;
            if isempty(selectedRelPath)
                return;
            end
            fullPath = fullfile(app.ProjectRoot, selectedRelPath);
            if ~isfile(fullPath)
                app.showError(sprintf('Sample file not found: %s', selectedRelPath));
                return;
            end
            app.ImagePathField.Value = fullPath;
            app.refreshCaseName();
            t = app.Theme;
            app.setStatus('Sample loaded. Ready to run screening.', t.text, t.accent);
        end

        function buildPerformanceCard(app, parent, row)
            t = app.Theme;
            [~, grid] = app.card(parent, row, {14, 18, 18, 16});
            app.caption(grid, 1, 'VALIDATION PERFORMANCE');

            [sensitivity, specificity] = app.frozenValidationMetrics();
            [sensRow, app.SensitivityLabel] = app.metricLine(grid, 2, 'Sensitivity', ...
                sensitivity, t.green);
            [specRow, app.SpecificityLabel] = app.metricLine(grid, 3, 'Specificity', ...
                specificity, t.accent);
            sensRow.Tooltip = 'Referable DR, ICDR >= 2.';
            specRow.Tooltip = 'Referable DR, ICDR >= 2.';

            note = uilabel(grid, 'Text', 'Referable DR  ·  n = 550 validation', ...
                'FontSize', 9, 'FontColor', t.faint);
            note.Layout.Row = 4;
        end

        function buildPipelineCard(app, parent, row)
            t = app.Theme;
            app.StageNames = {'Quality gate', 'Preprocessing', ...
                'CNN grading', 'Grad-CAM', 'Lesion evidence', 'ICDR rules'};
            heights = [{14}, repmat({17}, 1, numel(app.StageNames))];
            [~, grid] = app.card(parent, row, heights);
            grid.RowSpacing = 2;
            app.caption(grid, 1, 'PIPELINE STAGES');
            app.StageMarks = gobjects(1, numel(app.StageNames));
            for index = 1:numel(app.StageNames)
                line = uigridlayout(grid, [1, 2]);
                line.Layout.Row = index + 1;
                line.ColumnWidth = {14, '1x'};
                line.RowHeight = {'1x'};
                line.Padding = [0, 0, 0, 0];
                line.ColumnSpacing = 6;
                line.BackgroundColor = t.surface;
                mark = uilabel(line, 'Text', '○', 'FontSize', 10, ...
                    'FontColor', t.faint);
                mark.Layout.Column = 1;
                name = uilabel(line, 'Text', app.StageNames{index}, ...
                    'FontSize', 10.5, 'FontColor', t.muted);
                name.Layout.Column = 2;
                app.StageMarks(index) = mark;
            end
        end

        function setStageMarks(app, states)
            t = app.Theme;
            for index = 1:numel(app.StageMarks)
                if index <= numel(states) && states(index)
                    app.StageMarks(index).Text = '●';
                    app.StageMarks(index).FontColor = t.green;
                else
                    app.StageMarks(index).Text = '○';
                    app.StageMarks(index).FontColor = t.faint;
                end
            end
        end

        function [line, valueLabel] = metricLine(app, parent, row, name, value, colour)
            t = app.Theme;
            line = uigridlayout(parent, [1, 2]);
            line.Layout.Row = row;
            line.ColumnWidth = {'1x', 'fit'};
            line.RowHeight = {'1x'};
            line.Padding = [0, 0, 0, 0];
            line.ColumnSpacing = 8;
            line.BackgroundColor = t.surface;
            label = uilabel(line, 'Text', name, ...
                'FontSize', 11, 'FontColor', t.muted);
            label.Layout.Column = 1;
            valueLabel = uilabel(line, 'Text', value, ...
                'FontSize', 12.5, 'FontWeight', 'bold', 'FontColor', colour, ...
                'HorizontalAlignment', 'right');
            valueLabel.Layout.Column = 2;
        end

        function [sensitivity, specificity] = frozenValidationMetrics(app)
            sensitivity = 'not recorded';
            specificity = 'not recorded';
            configPath = fullfile(app.ProjectRoot, 'config', 'default.json');
            if ~isfile(configPath)
                return;
            end
            try
                config = jsondecode(fileread(configPath));
            catch
                return;
            end
            if ~isfield(config, 'operating_point')
                return;
            end
            operatingPoint = config.operating_point;
            if isfield(operatingPoint, 'validation_sensitivity')
                sensitivity = sprintf('%.1f%%', ...
                    operatingPoint.validation_sensitivity * 100);
            end
            if isfield(operatingPoint, 'validation_specificity')
                specificity = sprintf('%.1f%%', ...
                    operatingPoint.validation_specificity * 100);
            end
        end

        % -------------------------------------------------------- workspace
        function buildWorkspace(app, parent)
            t = app.Theme;
            main = uigridlayout(parent, [5, 1]);
            main.Layout.Column = 2;
            main.RowHeight = {44, 30, 94, 20, '1x'};
            main.ColumnWidth = {'1x'};
            main.Padding = [0, 0, 0, 0];
            main.RowSpacing = 12;
            main.BackgroundColor = t.bg;
            app.WorkspaceGrid = main;

            % --- Row 1: Top Action Bar (DocuVerse search & actions)
            app.buildTopBar(main);

            % --- Row 2: Overview Headline
            app.buildHeaderTitle(main);

            % --- Row 3: 4 KPI Cards (DocuVerse top stat cards)
            app.buildVerdictStrip(main);

            % --- Row 4: Evidence Warning
            app.EvidenceWarningValue = uilabel(main, 'Text', '', ...
                'FontSize', 10.5, 'FontColor', t.amber, 'WordWrap', 'on', ...
                'VerticalAlignment', 'center');
            app.EvidenceWarningValue.Layout.Row = 4;

            % --- Row 5: Content Split (Left = 2x2 Square Images, Right = Clinical Evidence)
            content = uigridlayout(main, [1, 2]);
            content.Layout.Row = 5;
            content.ColumnWidth = {'1.38x', '1x'};
            content.RowHeight = {'1x'};
            content.Padding = [0, 0, 0, 0];
            content.ColumnSpacing = 14;
            content.BackgroundColor = t.bg;
            app.ContentSplitGrid = content;

            app.buildImageGrid(content);
            app.buildEvidenceColumn(content);
            app.buildNarrativeStore(main);
        end

        function buildTopBar(app, parent)
            t = app.Theme;
            top = uigridlayout(parent, [1, 6]);
            top.Layout.Row = 1;
            top.ColumnWidth = {'1x', 'fit', 'fit', 'fit', 'fit', 'fit'};
            top.RowHeight = {'1x'};
            top.Padding = [0, 0, 0, 0];
            top.ColumnSpacing = 10;
            top.BackgroundColor = t.bg;
            app.TopBarGrid = top;

            % Search / Input path pill (DocuVerse search bar)
            app.ImagePathField = uieditfield(top, 'text', ...
                'Placeholder', '🔍  Selected fundus image path or paste file path here...', ...
                'FontSize', 11.5, 'FontColor', t.text, ...
                'BackgroundColor', t.surface);
            app.ImagePathField.Layout.Column = 1;
            app.ImagePathField.ValueChangedFcn = @(~, ~) app.refreshCaseName();

            % Badges
            [threshold, frozenOn] = app.frozenBadgeFacts();
            app.OperatingBadge = uilabel(top, 'Text', ...
                sprintf('  📅 Frozen %s (τ=%s)  ', frozenOn, threshold), ...
                'FontSize', 10.5, 'FontWeight', 'bold', ...
                'FontColor', t.muted, 'BackgroundColor', t.surface, ...
                'HorizontalAlignment', 'center');
            app.OperatingBadge.Layout.Column = 2;

            app.SealedBadge = uilabel(top, 'Text', ...
                '  🔒 Sealed: Untouched  ', ...
                'FontSize', 10.5, 'FontWeight', 'bold', ...
                'FontColor', t.green, 'BackgroundColor', t.greenTint, ...
                'HorizontalAlignment', 'center');
            app.SealedBadge.Layout.Column = 3;

            app.ThemeToggleButton = uibutton(top, 'push', ...
                'Text', '🌙 Dark Mode', ...
                'FontSize', 10.5, 'FontColor', t.text, ...
                'BackgroundColor', t.surface, ...
                'Tooltip', 'Switch between Light Glass and Dark Pro themes', ...
                'ButtonPushedFcn', @(~, ~) app.toggleTheme());
            app.ThemeToggleButton.Layout.Column = 4;

            % Secondary Action: Reset Button
            app.ResetButton = uibutton(top, 'push', ...
                'Text', '↺ Reset', ...
                'FontSize', 11, 'FontColor', t.muted, ...
                'BackgroundColor', t.surface, ...
                'Tooltip', 'Reset canvas for next screening', ...
                'ButtonPushedFcn', @(~, ~) app.resetApp());
            app.ResetButton.Layout.Column = 5;

            % Primary Action: Run Screening Button (DocuVerse emerald button)
            app.RunButton = uibutton(top, 'push', ...
                'Text', '▶  Run Screening', ...
                'FontSize', 12, 'FontWeight', 'bold', ...
                'FontColor', t.accentInk, 'BackgroundColor', t.accent, ...
                'Tooltip', 'Run full triage pipeline (Enter)', ...
                'ButtonPushedFcn', @(~, ~) app.runScreening());
            app.RunButton.Layout.Column = 6;
        end

        function buildHeaderTitle(app, parent)
            t = app.Theme;
            heading = uigridlayout(parent, [1, 2]);
            heading.Layout.Row = 2;
            heading.ColumnWidth = {'1x', 'fit'};
            heading.RowHeight = {'1x'};
            heading.Padding = [0, 0, 0, 0];
            heading.ColumnSpacing = 8;
            heading.BackgroundColor = t.bg;
            app.HeaderTitleGrid = heading;

            titleBox = uigridlayout(heading, [1, 2]);
            titleBox.Layout.Column = 1;
            titleBox.ColumnWidth = {'fit', '1x'};
            titleBox.RowHeight = {'1x'};
            titleBox.Padding = [0, 0, 0, 0];
            titleBox.ColumnSpacing = 10;
            titleBox.BackgroundColor = t.bg;

            app.OverviewTitle = uilabel(titleBox, 'Text', 'Overview', ...
                'FontSize', 20, 'FontWeight', 'bold', 'FontColor', t.text);
            app.OverviewTitle.Layout.Column = 1;

            app.OverviewSubtitle = uilabel(titleBox, ...
                'Text', 'Diabetic Retinopathy Automated Screening & Triage', ...
                'FontSize', 11, 'FontColor', t.muted, ...
                'VerticalAlignment', 'bottom');
            app.OverviewSubtitle.Layout.Column = 2;

            app.ExportButton = uibutton(heading, 'push', ...
                'Text', '📄 Generate Report', 'Enable', 'off', ...
                'FontSize', 11, 'FontColor', t.muted, ...
                'BackgroundColor', t.surface, ...
                'Tooltip', 'Export PDF report and clinical figures', ...
                'ButtonPushedFcn', @(~, ~) app.exportReport());
            app.ExportButton.Layout.Column = 2;
        end

        function buildVerdictStrip(app, parent)
            t = app.Theme;
            strip = uigridlayout(parent, [1, 4]);
            strip.Layout.Row = 3;
            strip.ColumnWidth = {'1.4x', '1x', '1x', '1x'};
            strip.RowHeight = {'1x'};
            strip.Padding = [0, 0, 0, 0];
            strip.ColumnSpacing = 12;
            strip.BackgroundColor = t.bg;
            app.StripGrid = strip;

            [app.DecisionCard, decisionGrid] = app.tile(strip, 1);
            app.DecisionGrid = decisionGrid;
            app.caption(decisionGrid, 1, 'TRIAGE VERDICT');
            app.DecisionValue = uilabel(decisionGrid, 'Text', '--', ...
                'FontSize', 22, 'FontWeight', 'bold', 'FontColor', t.muted);
            app.DecisionValue.Layout.Row = 2;
            app.DecisionCaption = uilabel(decisionGrid, ...
                'Text', 'Awaiting a case', ...
                'FontSize', 10, 'FontColor', t.faint, 'WordWrap', 'on');
            app.DecisionCaption.Layout.Row = 3;

            [~, probabilityGrid] = app.tile(strip, 2);
            app.caption(probabilityGrid, 1, 'REFERABLE RISK');
            app.ProbabilityValue = uilabel(probabilityGrid, 'Text', '--', ...
                'FontSize', 22, 'FontWeight', 'bold', 'FontColor', t.muted);
            app.ProbabilityValue.Layout.Row = 2;
            app.ProbabilityCaption = uilabel(probabilityGrid, ...
                'Text', 'Calibrated risk score', ...
                'FontSize', 10, 'FontColor', t.faint);
            app.ProbabilityCaption.Layout.Row = 3;

            [~, levelGrid] = app.tile(strip, 3);
            app.caption(levelGrid, 1, 'ICDR SEVERITY');
            app.LevelValue = uilabel(levelGrid, 'Text', '--', ...
                'FontSize', 22, 'FontWeight', 'bold', 'FontColor', t.muted);
            app.LevelValue.Layout.Row = 2;
            app.LevelNameValue = uilabel(levelGrid, 'Text', 'Not graded', ...
                'FontSize', 10, 'FontColor', t.faint, 'WordWrap', 'on');
            app.LevelNameValue.Layout.Row = 3;

            [~, qualityGrid] = app.tile(strip, 4);
            app.caption(qualityGrid, 1, 'IMAGE QUALITY');
            app.QualityValue = uilabel(qualityGrid, 'Text', '--', ...
                'FontSize', 16, 'FontWeight', 'bold', 'FontColor', t.muted);
            app.QualityValue.Layout.Row = 2;
            app.QualityCaption = uilabel(qualityGrid, 'Text', 'Not assessed', ...
                'FontSize', 10, 'FontColor', t.faint, 'WordWrap', 'on');
            app.QualityCaption.Layout.Row = 3;
        end

        function buildNarrativeStore(app, parent)
            store = uipanel(parent, 'Visible', 'off', 'BorderType', 'none');
            store.Layout.Row = 4;
            storeGrid = uigridlayout(store, [6, 1]);
            app.AgreementValue = uilabel(storeGrid, 'Text', '');
            app.AgreementValue.Layout.Row = 1;
            app.EscalationValue = uilabel(storeGrid, 'Text', '');
            app.EscalationValue.Layout.Row = 2;
            app.AdviceValue = uilabel(storeGrid, 'Text', '');
            app.AdviceValue.Layout.Row = 3;

            % Retain hidden fields for test/demo script compatibility
            app.ModelPathField = uieditfield(storeGrid, 'text', 'Visible', 'off');
            app.ModelPathField.Layout.Row = 4;
            app.CalibrationPathField = uieditfield(storeGrid, 'text', 'Visible', 'off');
            app.CalibrationPathField.Layout.Row = 5;
            app.ConfigPathField = uieditfield(storeGrid, 'text', 'Visible', 'off');
            app.ConfigPathField.Layout.Row = 6;
        end

        function buildImageGrid(app, parent)
            t = app.Theme;
            images = uigridlayout(parent, [2, 2]);
            images.Layout.Column = 1;
            images.RowHeight = {'1x', '1x'};
            images.ColumnWidth = {'1x', '1x'};
            images.Padding = [0, 0, 0, 0];
            images.RowSpacing = 12;
            images.ColumnSpacing = 12;
            images.BackgroundColor = t.bg;
            app.ImagesGrid = images;

            app.OriginalAxes = app.imageCard(images, 1, 1, ...
                'Original fundus', 'As captured');
            app.ProcessedAxes = app.imageCard(images, 1, 2, ...
                'Preprocessed', 'Shared with training');
            app.GradCAMAxes = app.imageCard(images, 2, 1, ...
                'Grad-CAM', 'Where the network looked');
            [app.CandidateAxes, app.CandidateCaption] = app.imageCard( ...
                images, 2, 2, 'Lesion candidates', 'Evidence channel');
        end

        function [ax, subtitleLabel] = imageCard(app, parent, row, column, ...
                titleText, subtitleText)
            t = app.Theme;
            card = uipanel(parent, 'BorderType', 'line', ...
                'BorderColor', t.border, ...
                'BackgroundColor', t.surface);
            card.Layout.Row = row;
            card.Layout.Column = column;

            grid = uigridlayout(card, [2, 1]);
            grid.RowHeight = {24, '1x'};
            grid.ColumnWidth = {'1x'};
            grid.Padding = [8, 6, 8, 6];
            grid.RowSpacing = 4;
            grid.BackgroundColor = t.surface;

            heading = uigridlayout(grid, [1, 2]);
            heading.Layout.Row = 1;
            heading.ColumnWidth = {'fit', '1x'};
            heading.RowHeight = {'1x'};
            heading.Padding = [0, 0, 0, 0];
            heading.ColumnSpacing = 8;
            heading.BackgroundColor = t.surface;

            titleLabel = uilabel(heading, 'Text', titleText, ...
                'FontSize', 12, 'FontWeight', 'bold', 'FontColor', t.text);
            titleLabel.Layout.Column = 1;
            subtitleLabel = uilabel(heading, 'Text', subtitleText, ...
                'FontSize', 10, 'FontColor', t.faint);
            subtitleLabel.Layout.Column = 2;

            ax = uiaxes(grid);
            ax.Layout.Row = 2;
            app.blankAxes(ax);

            app.registerCard(card, grid);
        end

        function blankAxes(app, ax)
            t = app.Theme;
            ax.Color = t.axesMatte;
            ax.XTick = [];
            ax.YTick = [];
            ax.Box = 'off';
            ax.XColor = 'none';
            ax.YColor = 'none';
            axis(ax, 'square');
            pbaspect(ax, [1 1 1]);
            title(ax, '');
            try
                ax.LooseInset = [0, 0, 0, 0];
            catch
            end
            try
                ax.Toolbar.Visible = 'off';
            catch
            end
        end

        function buildEvidenceColumn(app, parent)
            t = app.Theme;
            evidenceCol = uigridlayout(parent, [2, 1]);
            evidenceCol.Layout.Column = 2;
            evidenceCol.RowHeight = {'1x', '1.35x'};
            evidenceCol.ColumnWidth = {'1x'};
            evidenceCol.Padding = [0, 0, 0, 0];
            evidenceCol.RowSpacing = 12;
            evidenceCol.BackgroundColor = t.bg;
            app.EvidenceColGrid = evidenceCol;

            [~, evidenceGrid] = app.card(evidenceCol, 1, {16, '1x'});
            app.caption(evidenceGrid, 1, 'EVIDENCE AND AGREEMENT');
            app.EvidenceValue = uitextarea(evidenceGrid, 'Editable', 'off', ...
                'Value', {'Awaiting a case.'}, 'WordWrap', 'on', ...
                'FontName', 'monospace', 'FontSize', 11, ...
                'FontColor', t.text, 'BackgroundColor', t.field);
            app.EvidenceValue.Layout.Row = 2;

            [~, traceGrid] = app.card(evidenceCol, 2, {16, '1x'});
            app.caption(traceGrid, 1, 'ICDR RULE TRACE');
            app.RuleTraceArea = uitextarea(traceGrid, 'Editable', 'off', ...
                'Value', {'Awaiting a case.'}, 'WordWrap', 'on', ...
                'FontName', 'monospace', 'FontSize', 10.5, ...
                'FontColor', t.muted, 'BackgroundColor', t.field);
            app.RuleTraceArea.Layout.Row = 2;
        end

        % ------------------------------------------------- layout primitives
        function [card, grid] = card(app, parent, row, rowHeights, column)
            t = app.Theme;
            card = uipanel(parent, 'BorderType', 'line', ...
                'BorderColor', t.border, ...
                'BackgroundColor', t.surface);
            card.Layout.Row = row;
            if nargin >= 5
                card.Layout.Column = column;
            end
            grid = uigridlayout(card, [numel(rowHeights), 1]);
            grid.RowHeight = rowHeights;
            grid.ColumnWidth = {'1x'};
            grid.Padding = [12, 10, 12, 10];
            grid.RowSpacing = 4;
            grid.BackgroundColor = t.surface;

            app.registerCard(card, grid);
        end

        function [card, grid] = tile(app, parent, column)
            t = app.Theme;
            card = uipanel(parent, 'BorderType', 'line', ...
                'BorderColor', t.border, ...
                'BackgroundColor', t.surface);
            card.Layout.Column = column;
            grid = uigridlayout(card, [3, 1]);
            grid.RowHeight = {12, 32, 28};
            grid.ColumnWidth = {'1x'};
            grid.Padding = [12, 8, 12, 6];
            grid.RowSpacing = 2;
            grid.BackgroundColor = t.surface;

            app.registerCard(card, grid);
        end

        function label = caption(app, parent, row, text)
            t = app.Theme;
            label = uilabel(parent, 'Text', text, ...
                'FontSize', 9.5, 'FontWeight', 'bold', 'FontColor', t.faint);
            label.Layout.Row = row;
            app.registerLabel(label, 'caption');
        end

        function registerCard(app, panel, grid)
            entry = struct('panel', panel, 'grid', grid);
            app.RegisteredCards{end + 1} = entry;
        end

        function registerLabel(app, label, role)
            entry = struct('label', label, 'role', role);
            app.RegisteredLabels{end + 1} = entry;
        end

        function applyTheme(app)
            t = app.Theme;

            app.UIFigure.Color = t.bg;
            if ~isempty(app.RootGrid) && isvalid(app.RootGrid)
                app.RootGrid.BackgroundColor = t.bg;
            end
            if ~isempty(app.SidebarCard) && isvalid(app.SidebarCard)
                app.SidebarCard.BackgroundColor = t.surface;
                app.SidebarCard.BorderColor = t.border;
            end
            if ~isempty(app.SidebarGrid) && isvalid(app.SidebarGrid)
                app.SidebarGrid.BackgroundColor = t.surface;
            end
            if ~isempty(app.WorkspaceGrid) && isvalid(app.WorkspaceGrid)
                app.WorkspaceGrid.BackgroundColor = t.bg;
            end
            if ~isempty(app.TopBarGrid) && isvalid(app.TopBarGrid)
                app.TopBarGrid.BackgroundColor = t.bg;
            end
            if ~isempty(app.HeaderTitleGrid) && isvalid(app.HeaderTitleGrid)
                app.HeaderTitleGrid.BackgroundColor = t.bg;
            end
            if ~isempty(app.StripGrid) && isvalid(app.StripGrid)
                app.StripGrid.BackgroundColor = t.bg;
            end
            if ~isempty(app.ContentSplitGrid) && isvalid(app.ContentSplitGrid)
                app.ContentSplitGrid.BackgroundColor = t.bg;
            end
            if ~isempty(app.ImagesGrid) && isvalid(app.ImagesGrid)
                app.ImagesGrid.BackgroundColor = t.bg;
            end
            if ~isempty(app.EvidenceColGrid) && isvalid(app.EvidenceColGrid)
                app.EvidenceColGrid.BackgroundColor = t.bg;
            end

            for index = 1:numel(app.RegisteredCards)
                entry = app.RegisteredCards{index};
                if isvalid(entry.panel)
                    entry.panel.BackgroundColor = t.surface;
                    entry.panel.BorderColor = t.border;
                end
                if isvalid(entry.grid)
                    entry.grid.BackgroundColor = t.surface;
                end
            end

            for index = 1:numel(app.RegisteredLabels)
                entry = app.RegisteredLabels{index};
                if isvalid(entry.label)
                    switch entry.role
                        case 'caption'
                            entry.label.FontColor = t.faint;
                    end
                end
            end

            if ~isempty(app.OverviewTitle) && isvalid(app.OverviewTitle)
                app.OverviewTitle.FontColor = t.text;
            end
            if ~isempty(app.OverviewSubtitle) && isvalid(app.OverviewSubtitle)
                app.OverviewSubtitle.FontColor = t.muted;
            end
            if ~isempty(app.OperatingBadge) && isvalid(app.OperatingBadge)
                app.OperatingBadge.BackgroundColor = t.surface;
                app.OperatingBadge.FontColor = t.muted;
            end
            if ~isempty(app.SealedBadge) && isvalid(app.SealedBadge)
                app.SealedBadge.BackgroundColor = t.greenTint;
                app.SealedBadge.FontColor = t.green;
            end
            if ~isempty(app.ThemeToggleButton) && isvalid(app.ThemeToggleButton)
                app.ThemeToggleButton.BackgroundColor = t.surface;
                app.ThemeToggleButton.FontColor = t.text;
                if strcmpi(t.name, 'light')
                    app.ThemeToggleButton.Text = '🌙 Dark Mode';
                else
                    app.ThemeToggleButton.Text = '☀ Light Glass';
                end
            end

            if ~isempty(app.ImagePathField) && isvalid(app.ImagePathField)
                app.ImagePathField.BackgroundColor = t.surface;
                app.ImagePathField.FontColor = t.text;
            end
            if ~isempty(app.SelectImageButton) && isvalid(app.SelectImageButton)
                app.SelectImageButton.BackgroundColor = t.field;
                app.SelectImageButton.FontColor = t.text;
            end
            if ~isempty(app.SampleCaseDropdown) && isvalid(app.SampleCaseDropdown)
                app.SampleCaseDropdown.BackgroundColor = t.field;
                app.SampleCaseDropdown.FontColor = t.text;
            end
            if ~isempty(app.RunButton) && isvalid(app.RunButton)
                if strcmp(app.RunButton.Enable, 'on')
                    app.RunButton.BackgroundColor = t.accent;
                    app.RunButton.FontColor = t.accentInk;
                else
                    app.RunButton.BackgroundColor = t.raised;
                    app.RunButton.FontColor = t.muted;
                end
            end
            if ~isempty(app.ResetButton) && isvalid(app.ResetButton)
                app.ResetButton.BackgroundColor = t.surface;
                app.ResetButton.FontColor = t.muted;
            end
            if ~isempty(app.ExportButton) && isvalid(app.ExportButton)
                app.ExportButton.BackgroundColor = t.surface;
                if strcmp(app.ExportButton.Enable, 'on')
                    app.ExportButton.FontColor = t.text;
                else
                    app.ExportButton.FontColor = t.muted;
                end
            end
            if ~isempty(app.StatusValue) && isvalid(app.StatusValue)
                app.StatusValue.FontColor = t.text;
            end
            if ~isempty(app.ProcessingTimeValue) && isvalid(app.ProcessingTimeValue)
                app.ProcessingTimeValue.FontColor = t.faint;
            end
            if ~isempty(app.SensitivityLabel) && isvalid(app.SensitivityLabel)
                app.SensitivityLabel.FontColor = t.green;
            end
            if ~isempty(app.SpecificityLabel) && isvalid(app.SpecificityLabel)
                app.SpecificityLabel.FontColor = t.accent;
            end

            if ~isempty(app.EvidenceValue) && isvalid(app.EvidenceValue)
                app.EvidenceValue.BackgroundColor = t.field;
                app.EvidenceValue.FontColor = t.text;
            end
            if ~isempty(app.RuleTraceArea) && isvalid(app.RuleTraceArea)
                app.RuleTraceArea.BackgroundColor = t.field;
                app.RuleTraceArea.FontColor = t.muted;
            end

            for ax = [app.OriginalAxes, app.ProcessedAxes, ...
                    app.GradCAMAxes, app.CandidateAxes]
                if ~isempty(ax) && isvalid(ax)
                    ax.Color = t.axesMatte;
                end
            end

            if ~isempty(app.ScreeningResult)
                app.renderVerdict(app.ScreeningResult);
            else
                app.clearResultSurfaces();
            end
        end

        % ----------------------------------------------------------- wiring
        function applyDefaults(app, varargin)
            configPath = fullfile(app.ProjectRoot, 'config', 'default.json');
            [checkpointPath, calibrationPath] = ...
                app.frozenOperatingPoint(configPath);
            if mod(numel(varargin), 2) ~= 0
                error('app:InvalidUIOptions', 'UI options must be name-value pairs.');
            end
            for index = 1:2:numel(varargin)
                name = lower(char(varargin{index}));
                value = char(varargin{index + 1});
                switch name
                    case 'configpath'
                        configPath = value;
                    case 'checkpointpath'
                        checkpointPath = value;
                    case 'calibrationpath'
                        calibrationPath = value;
                    case 'theme'
                        app.setTheme(value);
                    otherwise
                        error('app:InvalidUIOptions', 'Unknown UI option: %s', name);
                end
            end
            app.ConfigPathField.Value = configPath;
            app.ModelPathField.Value = checkpointPath;
            app.CalibrationPathField.Value = calibrationPath;
            app.ConfigPathField.Tooltip = configPath;
            app.ModelPathField.Tooltip = checkpointPath;
            app.CalibrationPathField.Tooltip = calibrationPath;
        end

        function [threshold, frozenOn] = frozenBadgeFacts(app)
            threshold = 'unset';
            frozenOn = 'unset';
            configPath = fullfile(app.ProjectRoot, 'config', 'default.json');
            if ~isfile(configPath)
                return;
            end
            try
                config = jsondecode(fileread(configPath));
            catch
                return;
            end
            if ~isfield(config, 'operating_point')
                return;
            end
            operatingPoint = config.operating_point;
            if isfield(operatingPoint, 'referable_threshold')
                threshold = sprintf('%.2f', operatingPoint.referable_threshold);
            end
            if isfield(operatingPoint, 'frozen_on')
                frozenOn = char(string(operatingPoint.frozen_on));
            end
        end

        function [checkpointPath, calibrationPath] = ...
                frozenOperatingPoint(app, configPath)
            checkpointPath = '';
            calibrationPath = '';
            if ~isfile(configPath)
                return;
            end
            config = jsondecode(fileread(configPath));
            if ~isfield(config, 'operating_point')
                return;
            end
            operatingPoint = config.operating_point;
            if isfield(operatingPoint, 'model')
                checkpointPath = fullfile(app.ProjectRoot, operatingPoint.model);
            end
            if isfield(operatingPoint, 'calibration')
                calibrationPath = fullfile(app.ProjectRoot, ...
                    operatingPoint.calibration);
                if isfolder(calibrationPath)
                    calibrationPath = fullfile(calibrationPath, ...
                        'temperature_fit.mat');
                end
            end
        end

        function selectImage(app)
            try
                [filename, directory] = uigetfile( ...
                    {'*.png;*.jpg;*.jpeg;*.tif;*.tiff', 'Fundus images'}, ...
                    'Select fundus image');
            catch exception
                app.showError(['File chooser unavailable (', ...
                    exception.message, ') Type or paste an image path into ', ...
                    'the top search bar instead.']);
                return;
            end
            if isequal(filename, 0)
                return;
            end
            app.ImagePathField.Value = fullfile(directory, filename);
            if ~isempty(app.SampleCaseDropdown) && isvalid(app.SampleCaseDropdown)
                app.SampleCaseDropdown.Value = app.SampleCaseDropdown.ItemsData{1};
            end
            app.refreshCaseName();
            app.setStatus('Image selected. Ready to run screening.', app.Theme.text, ...
                app.Theme.accent);
        end

        function refreshCaseName(app)
            t = app.Theme;
            imagePath = strtrim(app.ImagePathField.Value);
            if isempty(imagePath)
                app.CaseNameValue.Text = 'No image selected';
                app.CaseNameValue.FontColor = t.faint;
                app.CaseNameValue.Tooltip = '';
                return;
            end
            [~, name, extension] = fileparts(imagePath);
            app.CaseNameValue.Text = [name, extension];
            app.CaseNameValue.FontColor = t.text;
            app.CaseNameValue.Tooltip = imagePath;
        end

        function setStatus(app, text, textColour, dotColour)
            app.StatusValue.Text = text;
            app.StatusValue.FontColor = textColour;
            app.StatusDot.FontColor = dotColour;
        end

        function runScreening(app)
            t = app.Theme;
            imagePath = strtrim(app.ImagePathField.Value);
            app.refreshCaseName();
            if isempty(imagePath)
                app.showError('Select an image before running screening.');
                return;
            end
            app.setStatus('Running quality gate and pipeline...', t.text, t.amber);
            app.RunButton.Enable = 'off';
            app.RunButton.Text = 'Screening...';
            app.RunButton.BackgroundColor = t.raised;
            app.RunButton.FontColor = t.muted;
            app.clearResultSurfaces();
            drawnow;

            progress = uiprogressdlg(app.UIFigure, ...
                'Title', 'Screening in progress', ...
                'Message', 'Running quality gate, grading, Grad-CAM, and ICDR rules...', ...
                'Indeterminate', 'on', 'Cancelable', 'off');
            timer = tic;
            failure = '';
            try
                app.ScreeningResult = app.runCase(imagePath, ...
                    app.ModelPathField.Value, app.CalibrationPathField.Value, ...
                    app.ConfigPathField.Value);
                elapsed = toc(timer);
            catch exception
                failure = exception.message;
            end
            delete(progress);

            app.RunButton.Enable = 'on';
            app.RunButton.Text = '▶  Run Screening';
            app.RunButton.BackgroundColor = t.accent;
            app.RunButton.FontColor = t.accentInk;

            if ~isempty(failure)
                app.showError(failure);
                return;
            end
            app.ProcessingTimeValue.Text = sprintf( ...
                'Processing time  %.2f s', elapsed);
            app.renderResult(app.ScreeningResult);
            app.ExportButton.Enable = 'on';
            app.ExportButton.FontColor = t.text;
            app.setStatus('Screening complete', t.text, t.green);
        end

        function result = runCase(~, imagePath, checkpointPath, calibrationPath, configPath)
            result = app.runScreeningCase(imagePath, checkpointPath, ...
                calibrationPath, configPath);
        end

        % --------------------------------------------------------- rendering
        function renderResult(app, result)
            app.renderImages(result);
            app.renderVerdict(result);
            app.renderEvidence(result);
            app.playReveal();
        end

        function clearResultSurfaces(app)
            t = app.Theme;
            for label = [app.DecisionValue, app.ProbabilityValue, ...
                    app.LevelValue, app.QualityValue]
                label.Text = '--';
                label.FontColor = t.muted;
            end
            app.DecisionCaption.Text = 'Awaiting case screening';
            app.DecisionCaption.FontColor = t.faint;
            app.DecisionCard.BackgroundColor = t.surface;
            app.DecisionCard.BorderColor = t.border;
            if ~isempty(app.DecisionGrid) && isvalid(app.DecisionGrid)
                app.DecisionGrid.BackgroundColor = t.surface;
            end
            app.ProbabilityCaption.Text = 'Calibrated risk score';
            app.LevelNameValue.Text = 'Not graded';
            app.QualityCaption.Text = 'Not assessed';
            app.EvidenceWarningValue.Text = '';
            app.EvidenceWarningValue.BackgroundColor = 'none';
            app.EvidenceValue.Value = {'Awaiting a case.'};
            app.RuleTraceArea.Value = {'Awaiting a case.'};
            for ax = [app.OriginalAxes, app.ProcessedAxes, ...
                    app.GradCAMAxes, app.CandidateAxes]
                cla(ax);
                app.blankAxes(ax);
            end
            app.ImageObjects = struct();
            app.setStageMarks(false(1, numel(app.StageNames)));
        end

        % --------------------------------------------------------- animation
        function playReveal(app)
            if ~app.AnimationsEnabled
                app.settleReveal();
                return;
            end
            try
                app.tickStagesIn();
                app.fadeImagesIn();
                app.revealVerdict();
            catch
                app.settleReveal();
            end
        end

        function tickStagesIn(app)
            states = app.PendingReveal.stages;
            for index = 1:numel(app.StageMarks)
                app.setStageMarks(states & ((1:numel(states)) <= index));
                drawnow limitrate;
                pause(0.055);
            end
            app.setStageMarks(states);
        end

        function fadeImagesIn(app)
            if isempty(app.ImageObjects)
                return;
            end
            names = fieldnames(app.ImageObjects);
            frames = 14;
            for frame = 1:frames
                eased = 1 - (1 - frame / frames) ^ 3;
                for index = 1:numel(names)
                    handle = app.ImageObjects.(names{index});
                    if isempty(handle) || ~isvalid(handle)
                        continue;
                    end
                    handle.AlphaData = ...
                        max(0, min(1, eased * 1.7 - (index - 1) * 0.17));
                end
                drawnow limitrate;
                pause(0.016);
            end
            app.settleImages();
        end

        function settleImages(app)
            if isempty(app.ImageObjects)
                return;
            end
            names = fieldnames(app.ImageObjects);
            for index = 1:numel(names)
                handle = app.ImageObjects.(names{index});
                if ~isempty(handle) && isvalid(handle)
                    handle.AlphaData = 1;
                end
            end
        end

        function revealVerdict(app)
            t = app.Theme;
            reveal = app.PendingReveal;
            frames = 16;
            for frame = 1:frames
                eased = 1 - (1 - frame / frames) ^ 3;
                app.DecisionValue.FontColor = ...
                    t.surface + (reveal.decisionColour - t.surface) * eased;
                app.LevelValue.FontColor = ...
                    t.surface + (t.text - t.surface) * eased;
                app.QualityValue.FontColor = ...
                    t.surface + (reveal.qualityColour - t.surface) * eased;
                if ~isempty(reveal.probability)
                    app.ProbabilityValue.FontColor = t.surface + ...
                        (reveal.probabilityColour - t.surface) * eased;
                    app.ProbabilityValue.Text = sprintf('%.1f%%', ...
                        reveal.probability * 100 * eased);
                end
                drawnow limitrate;
                pause(0.014);
            end
            app.settleReveal();
        end

        function settleReveal(app)
            t = app.Theme;
            app.settleImages();
            if isempty(app.PendingReveal)
                return;
            end
            reveal = app.PendingReveal;
            app.setStageMarks(reveal.stages);
            app.DecisionValue.FontColor = reveal.decisionColour;
            app.LevelValue.FontColor = t.text;
            app.QualityValue.FontColor = reveal.qualityColour;
            if isempty(reveal.probability)
                app.ProbabilityValue.Text = '--';
                app.ProbabilityValue.FontColor = t.muted;
            else
                app.ProbabilityValue.Text = ...
                    sprintf('%.1f%%', reveal.probability * 100);
                app.ProbabilityValue.FontColor = reveal.probabilityColour;
            end
        end

        function renderImages(app, result)
            app.ImageObjects = struct();
            app.ImageObjects.original = app.drawImage(app.OriginalAxes, ...
                localDisplay(result.originalImage));
            app.ImageObjects.processed = app.drawImage(app.ProcessedAxes, ...
                localDisplay(result.processedImage));
            if isfield(result.gradCAMResult, 'overlay')
                app.ImageObjects.gradcam = app.drawImage(app.GradCAMAxes, ...
                    result.gradCAMResult.overlay);
            else
                app.ImageObjects.gradcam = app.drawPlaceholder( ...
                    app.GradCAMAxes, ...
                    'Not generated: inference did not reach Grad-CAM.');
            end
            if isfield(result.lesionCandidateEvidence, 'candidateOverlay')
                app.ImageObjects.candidate = app.drawImage(app.CandidateAxes, ...
                    localDisplay(result.lesionCandidateEvidence.candidateOverlay));
            else
                app.ImageObjects.candidate = app.drawPlaceholder( ...
                    app.CandidateAxes, ...
                    'Not generated: no candidate overlay for this case.');
            end
        end

        function handle = drawImage(app, ax, image)
            cla(ax);
            handle = imshow(image, 'Parent', ax);
            app.blankAxes(ax);
            axis(ax, 'square');
            pbaspect(ax, [1 1 1]);
            if app.AnimationsEnabled
                handle.AlphaData = 0;
            end
        end

        function handle = drawPlaceholder(app, ax, message)
            t = app.Theme;
            cla(ax);
            app.blankAxes(ax);
            axis(ax, 'square');
            pbaspect(ax, [1 1 1]);
            text(ax, 0.5, 0.5, message, 'Units', 'normalized', ...
                'HorizontalAlignment', 'center', 'Color', t.faint, ...
                'FontSize', 11);
            handle = gobjects(0);
        end

        function renderVerdict(app, result)
            t = app.Theme;

            decision = char(result.threeWayDecision.decision);
            [decisionColour, decisionMeaning] = localDecisionStyle(decision, t);
            app.DecisionValue.Text = upper(decision);

            switch lower(decision)
                case 'auto-clear'
                    cardBg = t.greenTint;
                    cardBorder = t.green;
                case 'refer'
                    cardBg = t.amberTint;
                    cardBorder = t.amber;
                case 'escalate'
                    cardBg = t.redTint;
                    cardBorder = t.red;
                otherwise
                    cardBg = t.surface;
                    cardBorder = t.border;
            end
            app.DecisionCard.BackgroundColor = cardBg;
            app.DecisionCard.BorderColor = cardBorder;
            if ~isempty(app.DecisionGrid) && isvalid(app.DecisionGrid)
                app.DecisionGrid.BackgroundColor = cardBg;
            end
            app.DecisionCaption.Text = decisionMeaning;
            app.DecisionCaption.FontColor = t.text;

            probability = result.calibratedReferableProbability;
            if isempty(probability)
                probabilityColour = t.muted;
                app.ProbabilityCaption.Text = 'Not computed';
            else
                probabilityColour = localProbabilityColour(probability, t);
                app.ProbabilityCaption.Text = 'Calibrated risk score';
            end

            level = result.predictedICDRLevel;
            app.LevelValue.Text = localText(level);
            app.LevelNameValue.Text = localLevelName(level);

            qualityClass = char(result.qualityResult.class);
            app.QualityValue.Text = qualityClass;

            app.PendingReveal = struct( ...
                'decisionColour', decisionColour, ...
                'probability', probability, ...
                'probabilityColour', probabilityColour, ...
                'qualityColour', localQualityColour(qualityClass, t), ...
                'stages', localStageStates(result));

            if app.AnimationsEnabled
                app.DecisionValue.FontColor = t.surface;
                app.LevelValue.FontColor = t.surface;
                app.QualityValue.FontColor = t.surface;
                app.ProbabilityValue.FontColor = t.surface;
                app.ProbabilityValue.Text = '0.0%';
            else
                app.settleReveal();
            end

            advice = localJoin(result.qualityAdvice);
            if strcmpi(advice, 'None')
                app.QualityCaption.Text = 'No recapture needed';
            else
                app.QualityCaption.Text = advice;
            end
            app.AdviceValue.Text = sprintf('Recapture advice: %s', advice);

            app.AgreementValue.Text = sprintf('Agreement: %s', ...
                char(result.agreementStatus));
            app.EscalationValue.Text = sprintf('Decision reason: %s', ...
                localDecisionReason(result));

            evidenceSource = localEvidenceSource(result);
            app.CandidateCaption.Text = evidenceSource;
            app.EvidenceWarningValue.Text = sprintf( ...
                ['  Evidence channel: %s. All objects remain candidates: ' ...
                'this is provisional and is not clinically validated ' ...
                'lesion segmentation.'], evidenceSource);
            app.EvidenceWarningValue.BackgroundColor = t.amberTint;
        end

        function renderEvidence(app, result)
            app.EvidenceValue.Value = localEvidenceLines(result);
            if isfield(result.icdrRuleResult, 'ruleTrace')
                app.RuleTraceArea.Value = ...
                    strsplit(char(result.icdrRuleResult.ruleTrace), newline);
            else
                app.RuleTraceArea.Value = ...
                    {'Rule engine not run: the quality gate stopped inference.'};
            end
        end

        function exportReport(app)
            t = app.Theme;
            if isempty(app.ScreeningResult)
                app.showError('Run screening before exporting a report.');
                return;
            end
            app.ExportButton.Enable = 'off';
            app.ExportButton.Text = 'Exporting...';
            app.setStatus('Rendering report...', t.text, t.amber);
            drawnow;

            progress = uiprogressdlg(app.UIFigure, 'Title', 'Exporting report', ...
                'Message', 'Rendering panels and writing the PDF...', ...
                'Indeterminate', 'on', 'Cancelable', 'off');
            failure = '';
            try
                app.LastReport = report.generate(app.ScreeningResult, ...
                    'ResultsRoot', fullfile(app.ProjectRoot, 'results'));
            catch exception
                failure = exception.message;
            end
            delete(progress);

            app.ExportButton.Enable = 'on';
            app.ExportButton.Text = '📄 Generate Report';
            if ~isempty(failure)
                app.showError(failure);
                return;
            end

            [~, name, extension] = fileparts(char(app.LastReport.reportPath));
            app.setStatus(sprintf('Report exported: %s%s', name, extension), ...
                t.text, t.green);
            app.StatusValue.Tooltip = char(app.LastReport.reportPath);
            uialert(app.UIFigure, sprintf('%s\n\n%s', ...
                'Report, four-panel figure, overlays and text companion written to:', ...
                char(app.LastReport.resultsDirectory)), 'Report exported', ...
                'Icon', 'success');
        end

        function showError(app, message)
            t = app.Theme;
            app.setStatus(message, t.red, t.red);
            app.StatusValue.Tooltip = message;
            app.RunButton.Enable = 'on';
            app.RunButton.Text = '▶  Run Screening';
        end
    end
end

function image = localDisplay(image)
if isinteger(image) || islogical(image)
    image = im2double(image);
else
    image = double(image);
end
if ndims(image) == 2 || size(image, 3) == 1
    image = repmat(image, 1, 1, 3);
end
image = min(max(image, 0), 1);
end

function [colour, meaning] = localDecisionStyle(decision, theme)
switch lower(decision)
    case 'auto-clear'
        colour = theme.green;
        meaning = 'No referable disease. Patient can be safely cleared.';
    case 'refer'
        colour = theme.amber;
        meaning = 'Referable DR detected. Route to ophthalmology.';
    case 'escalate'
        colour = theme.red;
        meaning = 'Pipeline will not decide alone. Specialist review required.';
    otherwise
        colour = theme.muted;
        meaning = 'Decision not produced.';
end
end

function states = localStageStates(result)
states = false(1, 6);
states(1) = isfield(result, 'qualityResult') && ~isempty(result.qualityResult);
states(2) = isfield(result, 'processedImage') && ~isempty(result.processedImage);
states(3) = isfield(result, 'predictedICDRLevel') && ...
    ~isempty(result.predictedICDRLevel);
states(4) = isfield(result, 'gradCAMResult') && ...
    isfield(result.gradCAMResult, 'overlay');
states(5) = isfield(result, 'lesionCandidateEvidence') && ...
    isfield(result.lesionCandidateEvidence, 'quadrantCounts');
states(6) = isfield(result, 'icdrRuleResult') && ...
    isfield(result.icdrRuleResult, 'ruleTrace');
end

function colour = localProbabilityColour(probability, theme)
if probability >= 0.40
    colour = theme.amber;
else
    colour = theme.green;
end
end

function colour = localQualityColour(qualityClass, theme)
switch lower(qualityClass)
    case 'gradable'
        colour = theme.green;
    case 'borderline'
        colour = theme.amber;
    case 'ungradable'
        colour = theme.red;
    otherwise
        colour = theme.muted;
end
end

function name = localLevelName(level)
if isempty(level)
    name = 'Not graded';
    return;
end
names = {'No apparent retinopathy', 'Mild non-proliferative', ...
    'Moderate non-proliferative', 'Severe non-proliferative', ...
    'Proliferative retinopathy'};
if isnumeric(level) && isscalar(level) && level >= 0 && level <= 4 ...
        && level == fix(level)
    name = names{level + 1};
else
    name = 'Not graded';
end
end

function text = localJoin(values)
if isempty(values)
    text = 'None';
elseif iscell(values)
    text = strjoin(cellfun(@char, values, 'UniformOutput', false), '; ');
else
    text = char(string(values));
end
end

function text = localText(value)
if isempty(value)
    text = '--';
elseif isnumeric(value)
    text = sprintf('%d', value);
else
    text = char(string(value));
end
end

function text = localDecisionReason(result)
if isfield(result.threeWayDecision, 'decisionReason')
    text = char(result.threeWayDecision.decisionReason);
else
    text = 'Quality gate stopped inference.';
end
end

function text = localEvidenceSource(result)
text = 'evidence channel unavailable';
if isfield(result, 'icdrRuleResult') && ...
        isfield(result.icdrRuleResult, 'evidenceSource')
    source = char(result.icdrRuleResult.evidenceSource);
    if ~isempty(source)
        text = source;
    end
end
end

function lines = localEvidenceLines(result)
lines = {};
lines{end + 1} = sprintf('Agreement       %s', char(result.agreementStatus));
lines{end + 1} = sprintf('Reason          %s', localDecisionReason(result));
lines{end + 1} = '';

if isfield(result.lesionCandidateEvidence, 'quadrantCounts')
    counts = result.lesionCandidateEvidence.quadrantCounts;
    total = size(result.lesionCandidateEvidence.candidateCoordinates, 1);
    lines{end + 1} = sprintf('Candidates      %d', total);
    lines{end + 1} = sprintf('ST / IT / SN / IN   %d / %d / %d / %d', ...
        counts.ST, counts.IT, counts.SN, counts.IN);
    if isfield(result.gradCAMResult, 'convolutionalLayerName')
        lines{end + 1} = sprintf('Grad-CAM layer  %s', ...
            char(result.gradCAMResult.convolutionalLayerName));
        lines{end + 1} = sprintf('Heatmap source  %s', ...
            char(result.gradCAMResult.rawHeatmapResolution));
    end
    lines{end + 1} = '';
    lines{end + 1} = 'Candidate evidence is provisional.';
else
    lines{end + 1} = 'Candidate counts  not generated';
end
end
