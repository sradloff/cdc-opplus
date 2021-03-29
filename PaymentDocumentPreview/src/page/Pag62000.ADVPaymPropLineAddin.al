#pragma implicitwith disable
page 62000 "ADV Paym. Prop. Line Addin"
{
    Caption = 'Document Capture Client Addin';
    DeleteAllowed = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    PageType = ListPart;
    Permissions = TableData "CDC Continia User Property" = rimd;
    SourceTable = "OPP Payment Proposal Line";

    layout
    {
        area(content)
        {

            usercontrol(CaptureUIWeb; "CDC Capture UI AddIn")
            {
                Visible = SHOWCAPTUREWEBUI;
                ApplicationArea = All;

                trigger OnControlAddIn(index: Integer; data: Text)
                begin
                    OnControlAddInEvent(Index, Data);
                end;

                trigger AddInReady()
                begin
                    AddInReady := TRUE;
                    UpdatePage;
                end;
            }
        }
    }

    actions
    {
    }

    trigger OnAfterGetRecord()
    var
        PurchInvHeader: Record "Purch. Inv. Header";
        PurchCrMemoHeader: Record "Purch. Cr. Memo Hdr.";
    begin
        IF (Rec."Applies-to Doc. Type" <> xRec."Applies-to Doc. Type") OR (Rec."Applies-to Doc. No." <> xRec."Applies-to Doc. No.") THEN BEGIN
            Document.SETCURRENTKEY("Created Doc. Table No.", "Created Doc. Subtype", "Created Doc. No.", "Created Doc. Ref. No.");
            Document.SETRANGE("Created Doc. Table No.", DATABASE::"Purchase Header");
            case Rec."Applies-to Doc. Type" of
                rec."Applies-to Doc. Type"::Invoice:
                    begin
                        if not PurchInvHeader.get(Rec."Applies-to Doc. No.") then
                            PurchInvHeader.Init();
                        Document.SETRANGE("Created Doc. Subtype", 2);
                        Document.SETRANGE("Created Doc. No.", PurchInvHeader."Pre-Assigned No.");
                    end;
                rec."Applies-to Doc. Type"::"Credit Memo":
                    begin
                        if not PurchCrMemoHeader.get(Rec."Applies-to Doc. No.") then
                            PurchCrMemoHeader.Init();
                        Document.SETRANGE("Created Doc. Subtype", 3);
                        Document.SETRANGE("Created Doc. No.", PurchCrMemoHeader."Pre-Assigned No.");
                    end;
            end;

            Document.SETFILTER("File Type", '%1|%2', Document."File Type"::OCR, Document."File Type"::XML);
            IF NOT Document.FINDFIRST THEN
                CLEAR(Document);

            UpdateImage;
            SendCommand(CaptureXmlDoc);
        END ELSE
            IF (SendAllPendingCommands AND (NOT CaptureXmlDoc.IsEmpty)) THEN BEGIN
                SendAllPendingCommands := FALSE;
                SendCommand(CaptureXmlDoc);
            END;
    end;

    trigger OnOpenPage()
    begin
        IF ContiniaUserProp.GET(USERID) AND (ContiniaUserProp."Image Zoom" > 0) THEN
            CurrZoom := ContiniaUserProp."Image Zoom"
        ELSE
            CurrZoom := 50;

        ShowCaptureUI := NOT WebClientMgt.IsWebClient;
        ShowCaptureWebUI := WebClientMgt.IsWebClient;

        IF ContiniaUserProp.GET(USERID) AND (ContiniaUserProp."Add-In Min Width" > 0) THEN
            AddInWidth := ContiniaUserProp."Add-In Min Width"
        ELSE
            AddInWidth := 725;

        CaptureAddinLib.BuildSetAddInWidthCommand(AddInWidth, CaptureXmlDoc);
    end;

    var
        Document: Record "CDC Document";
        ContiniaUserProp: Record "CDC Continia User Property";
        CaptureMgt: Codeunit "CDC Capture Management";
        CaptureAddinLib: Codeunit "CDC Capture RTC Library";
        WebClientMgt: Codeunit "CDC Web Client Management";
        TIFFMgt: Codeunit "CDC TIFF Management";
        CaptureXmlDoc: Codeunit "CSC XML Document";
        CaptureUISource: Text;
        Channel: Code[50];
        CurrentPageText: Text[250];
        CurrentZoomText: Text[30];
        HeaderFieldsFormName: Text[50];
        LineFieldsFormName: Text[50];
        MatchQty: Decimal;
        CurrZoom: Decimal;
        CurrentPageNo: Integer;
        Text001: Label '(%1 pages in total)';
        Text002: Label 'Page %1';
        AddInReady: Boolean;
        SendAllPendingCommands: Boolean;
        DisableCapture: Boolean;
        [InDataSet]
        ShowCaptureUI: Boolean;
        ShowCaptureWebUI: Boolean;
        Text003: Label '(1 page in total)';
        AddInWidth: Integer;

    internal procedure UpdateImage()
    var
        TempDocFileInfo: Record "CDC Temp. Doc. File Info.";
        TempFile: Record "CDC Temp File" temporary;
        "Page": Record "CDC Document Page";
        HasImage: Boolean;
        FileName: Text[1024];
    begin
        IF Document."No." = '' THEN
            IF NOT WebClientMgt.IsWebClient THEN
                CaptureAddinLib.BuildSetImageCommand(FileName, TRUE, CaptureXmlDoc);

        IF Document."File Type" = Document."File Type"::XML THEN
            HasImage := Document.GetVisualFile(TempFile)
        ELSE
            IF WebClientMgt.IsWebClient THEN BEGIN
                HasImage := Document.GetPngFile(TempFile, 1);
                IF NOT HasImage THEN
                    HasImage := Document.GetTiffFile(TempFile);
            END ELSE
                HasImage := Document.GetTiffFile(TempFile);

        IF (FileName = '') AND NOT HasImage THEN BEGIN
            CaptureAddinLib.BuildClearImageCommand(CaptureXmlDoc);
            UpdateCurrPageNo(0);
            EXIT;
        END ELSE
            IF (FileName = '') AND NOT WebClientMgt.IsWebClient THEN BEGIN
                FileName := TempFile.GetClientFilePath;
                CaptureAddinLib.BuildSetImageCommand(FileName, TRUE, CaptureXmlDoc);
            END ELSE
                IF Document."File Type" = Document."File Type"::XML THEN
                    CaptureAddinLib.BuildSetImageDataCommand(TempFile.GetContentAsDataUrl, TRUE, CaptureXmlDoc);

        UpdateCurrPageNo(1);

        CaptureAddinLib.BuildScrollTopCommand(CaptureXmlDoc);

        IF (ContiniaUserProp."Image Zoom" = 0) AND (Page.GET(Document."No.", 1)) AND (Page.Width > 0) THEN BEGIN
            IF NOT WebClientMgt.IsWebClient THEN
                CurrZoom := ROUND(((AddInWidth - 50) / Page.Width) * 100, 1, '<')
            ELSE
                CurrZoom := ROUND(((AddInWidth - 80) / Page.Width) * 100, 1, '<');
        END ELSE
            CurrZoom := ContiniaUserProp."Image Zoom";

        Zoom(CurrZoom, FALSE);

        IF Document."No. of Pages" = 1 THEN
            CaptureAddinLib.BuildTotalNoOfPagesTextCommand(Text003, CaptureXmlDoc)
        ELSE
            CaptureAddinLib.BuildTotalNoOfPagesTextCommand(STRSUBSTNO(Text001, Document."No. of Pages"), CaptureXmlDoc);
    end;

    internal procedure UpdateCurrPageNo(PageNo: Integer)
    var
        TempFile: Record "CDC Temp File" temporary;
        ImageManagement: Codeunit "CDC Image Management";
        ImageDataUrl: Text;
    begin
        Document.CALCFIELDS("No. of Pages");

        CurrentPageNo := PageNo;
        CurrentPageText := STRSUBSTNO(Text002, CurrentPageNo);

        IF (WebClientMgt.IsWebClient AND (PageNo > 0)) THEN BEGIN
            IF Document.GetPngFile(TempFile, PageNo) THEN
                ImageDataUrl := ImageManagement.GetImageDataAsJpegDataUrl(TempFile, 100)
            ELSE BEGIN
                IF Document.GetTiffFile(TempFile) THEN
                    ImageDataUrl := TIFFMgt.GetPageAsDataUrl(TempFile, PageNo);
            END;

            IF ImageDataUrl <> '' THEN
                CaptureAddinLib.BuildSetImageDataCommand(ImageDataUrl, TRUE, CaptureXmlDoc);
        END;

        CaptureAddinLib.BuildSetActivePageCommand(PageNo, CurrentPageText, CaptureXmlDoc);
    end;

    internal procedure ParsePageText(PageText: Text[30])
    var
        NewPageNo: Integer;
    begin
        IF STRPOS(PageText, ' ') = 0 THEN BEGIN
            IF EVALUATE(NewPageNo, PageText) THEN;
        END ELSE
            IF EVALUATE(NewPageNo, COPYSTR(PageText, STRPOS(PageText, ' '))) THEN;

        Document.CALCFIELDS("No. of Pages");
        IF (NewPageNo <= 0) OR (NewPageNo > Document."No. of Pages") THEN
            UpdateCurrPageNo(CurrentPageNo)
        ELSE
            UpdateCurrPageNo(NewPageNo);
    end;

    internal procedure Zoom(ZoomPct: Decimal; UpdateUserProp: Boolean)
    begin
        IF ZoomPct < 1 THEN
            ZoomPct := 1;
        CurrZoom := ZoomPct;
        CurrentZoomText := FORMAT(CurrZoom) + '%';

        IF UpdateUserProp THEN BEGIN
            IF NOT ContiniaUserProp.GET(USERID) THEN BEGIN
                ContiniaUserProp."User ID" := USERID;
                ContiniaUserProp."Image Zoom" := CurrZoom;
                ContiniaUserProp.INSERT;
            END ELSE BEGIN
                IF ContiniaUserProp."Image Zoom" <> CurrZoom THEN BEGIN
                    ContiniaUserProp."Image Zoom" := CurrZoom;
                    ContiniaUserProp.MODIFY;
                END;
            END;
        END;

        CaptureAddinLib.BuildZoomCommand(CurrZoom, CaptureXmlDoc);
        CaptureAddinLib.BuildZoomTextCommand(CurrentZoomText, CaptureXmlDoc);
    end;

    internal procedure SendCommand(var XmlDoc: Codeunit "CSC XML Document")
    var
        NewXmlDoc: Codeunit "CSC XML Document";
    begin
        IF NOT AddInReady AND WebClientMgt.IsWebClient THEN
            EXIT;

        CaptureAddinLib.XmlToText(XmlDoc, CaptureUISource);
        CaptureAddinLib.TextToXml(NewXmlDoc, CaptureUISource);

        IF WebClientMgt.IsWebClient THEN
            CurrPage.CaptureUIWeb.SourceValueChanged(CaptureUISource);

        CLEAR(CaptureXmlDoc);
    end;

    internal procedure SetConfig(NewHeaderFieldsFormName: Text[50]; NewLineFieldsFormName: Text[50]; NewChannel: Code[50])
    begin
        HeaderFieldsFormName := NewHeaderFieldsFormName;
        LineFieldsFormName := NewLineFieldsFormName;
        Channel := NewChannel;
    end;

    internal procedure HandleSimpleCommand(Command: Text[1024])
    begin
        CASE Command OF
            'ZoomIn':
                Zoom(ROUND(CurrZoom, 5, '<') + 5, TRUE);

            'ZoomOut':
                Zoom(ROUND(CurrZoom, 5, '>') - 5, TRUE);

            'FirstPage':
                BEGIN
                    Document.CALCFIELDS("No. of Pages");
                    IF Document."No. of Pages" > 0 THEN
                        UpdateCurrPageNo(1);
                END;

            'NextPage':
                BEGIN
                    Document.CALCFIELDS("No. of Pages");
                    IF CurrentPageNo < Document."No. of Pages" THEN
                        UpdateCurrPageNo(CurrentPageNo + 1);
                END;

            'PrevPage':
                BEGIN
                    IF CurrentPageNo > 1 THEN
                        UpdateCurrPageNo(CurrentPageNo - 1);
                END;

            'LastPage':
                BEGIN
                    Document.CALCFIELDS("No. of Pages");
                    UpdateCurrPageNo(Document."No. of Pages");
                END;
        END;

        SendCommand(CaptureXmlDoc);
    end;

    internal procedure HandleXmlCommand(Command: Text[1024]; var InXmlDoc: Codeunit "CSC XML Document")
    var
        XmlLib: Codeunit "CDC Xml Library";
        DocumentElement: Codeunit "CSC XML Node";
    begin
        InXmlDoc.GetDocumentElement(DocumentElement);
        CASE Command OF
            'ZoomTextChanged':
                BEGIN
                    CurrentZoomText := XmlLib.GetNodeText(DocumentElement, 'Text');
                    IF EVALUATE(CurrZoom, DELCHR(CurrentZoomText, '=', '%')) THEN;
                    Zoom(CurrZoom, TRUE);
                END;

            'PageTextChanged':
                BEGIN
                    CurrentPageText := XmlLib.GetNodeText(DocumentElement, 'Text');
                    ParsePageText(CurrentPageText);
                END;

            'ChangePage':
                UpdateCurrPageNo(XmlLib.Text2Int(XmlLib.GetNodeText(DocumentElement, 'NewPageNo')));

            'InfoPaneResized':
                AddInWidth := XmlLib.Text2Int(XmlLib.GetNodeText(DocumentElement, 'Width'));
        END;

        IF NOT CaptureXmlDoc.IsEmpty THEN
            SendCommand(CaptureXmlDoc);
    end;

    internal procedure SetSendAllPendingCommands(NewSendAllPendingCommands: Boolean)
    begin
        SendAllPendingCommands := NewSendAllPendingCommands;
    end;

    internal procedure SetDisableCapture(NewDisableCapture: Boolean)
    begin
        DisableCapture := NewDisableCapture;
    end;

    internal procedure ClearImage()
    var
        TempDocFileInfo: Record "CDC Temp. Doc. File Info.";
    begin
        CaptureAddinLib.BuildClearImageCommand(CaptureXmlDoc);
        UpdateCurrPageNo(0);
        SendCommand(CaptureXmlDoc);
        CurrPage.UPDATE(FALSE);
    end;

    internal procedure UpdatePage()
    begin
        UpdateImage;
        CaptureAddinLib.BuildCaptureEnabledCommand(FALSE, CaptureXmlDoc);
        SendCommand(CaptureXmlDoc);
        CurrPage.UPDATE(FALSE);
    end;

    local procedure OnControlAddInEvent(Index: Integer; Data: Variant)
    var
        InXmlDoc: Codeunit "CSC XML Document";
        DocumentElement: Codeunit "CSC XML Node";
        XmlLib: Codeunit "CDC Xml Library";
    begin
        IF Index = 0 THEN
            HandleSimpleCommand(Data)
        ELSE BEGIN
            CaptureAddinLib.TextToXml(InXmlDoc, Data);
            InXmlDoc.GetDocumentElement(DocumentElement);
            IF WebClientMgt.IsWebClient THEN
                HandleXmlCommand(XmlLib.GetNodeText(DocumentElement, 'Event'), InXmlDoc)
            ELSE
                HandleXmlCommand(XmlLib.GetNodeText(DocumentElement, 'Command'), InXmlDoc);
        END;
    end;
}
#pragma implicitwith restore
