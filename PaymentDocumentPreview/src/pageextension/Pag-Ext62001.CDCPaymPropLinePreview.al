pageextension 62001 "CDC Paym. Prop. Line Preview" extends "OPP Payment Proposal Lines"
{
    layout
    {
        addfirst(factboxes)
        {
            part(CDCCaptureUI; "ADV Paym. Prop. Line Addin")
            {
                Caption = 'Document';
                SubPageLink = "Journal Template Name" = field("Journal Template Name"),
                              "Journal Batch Name" = field("Journal Batch Name"),
                              "Line No." = field("Line No.");
                SubPageView = sorting("Journal Template Name", "Journal Batch Name", "Journal Line No.", "Line No.");
                ApplicationArea = All, Basic, Suite;
                AccessByPermission = tabledata "CDC Document Capture Setup" = R;
            }
        }
    }
}