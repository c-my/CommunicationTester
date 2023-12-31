unit SerialPortFrameUnit;

{$mode ObjFPC}{$H+}

interface

uses
    Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
    ComCtrls, Spin, SpinEx, Synaser, SerialManager, Types;

type

    { TMainForm }

    { SerialPortFrame }

    SerialPortFrame = class(TFrame)
        baudrateComboBox: TComboBox;
        TimerCheckBox: TCheckBox;
        closeButton: TButton;
        MSLabel: TLabel;
        RecvGroupBox: TGroupBox;
        SendEncodingComboBox: TComboBox;
        RecvEncodingComboBox: TComboBox;
        RecvEncodingLabel: TLabel;
        SerialSendGroupBox: TGroupBox;
        SendEncodingLabel: TLabel;
        SerialGroupBox: TGroupBox;
        RecvMemo: TMemo;
        openButton: TButton;
        databitComboBox: TComboBox;
        databitLabel: TLabel;
        SendMemo: TMemo;
        sendButton: TButton;
        ClearButton: TButton;
        SerialSendTimer: TTimer;
        TimerSpinEdit: TSpinEdit;
        stopbitComboBox: TComboBox;
        baudrateLabel: TLabel;
        paritybitComboBox: TComboBox;
        serialComboBox: TComboBox;
        stopbitLabel: TLabel;
        paritybitLabel: TLabel;
        serialLabel: TLabel;
        SerialListTimer: TTimer;


        procedure SerialParamComboBoxEditingDone(Sender: TObject);
        procedure ClearButtonClick(Sender: TObject);
        procedure closeButtonClick(Sender: TObject);
        procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
        procedure OpenButtonClick(Sender: TObject);
        procedure sendButtonClick(Sender: TObject);
        procedure SerialListTimerTimer(Sender: TObject);
        procedure SerialSendTimerTimer(Sender: TObject);
        procedure TimerCheckBoxChange(Sender: TObject);
        procedure TimerSpinEditChange(Sender: TObject);
    private
        serialThr: SerialThread;
        procedure OnSerialClose();
        procedure processReceivedSerialData(Data: string);
        procedure showWarnBox(message: string);
        function ConfigureSerial(serial: SerialThread): boolean;
        procedure OnSerialConnected();
        procedure OnSerialConnectedFailed();
    public
        constructor Create(TheOwner: TComponent); override;
    end;

var
    MainForm: SerialPortFrame;


implementation

{$R *.lfm}

{ SerialPortFrame }



procedure SerialPortFrame.ClearButtonClick(Sender: TObject);
begin
    RecvMemo.Clear();

end;

procedure SerialPortFrame.SerialParamComboBoxEditingDone(Sender: TObject);
begin
    if (serialThr <> nil) and serialThr.isConnected() then
        ConfigureSerial(serialThr);
end;



procedure SerialPortFrame.closeButtonClick(Sender: TObject);
begin
    serialThr.Close();
end;

procedure SerialPortFrame.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
    serialThr.Close();
end;



procedure SerialPortFrame.OpenButtonClick(Sender: TObject);

begin
    openButton.Enabled := False; // 防止多次点击

    serialThr := SerialThread.Create(True, serialComboBox.Text);
    serialThr.OnConnected := @OnSerialConnected;
    serialThr.OnConnectedFailed := @OnSerialConnectedFailed;
    serialThr.OnRecvData := @processReceivedSerialData;
    serialThr.OnClosed := @OnSerialClose;
    if not ConfigureSerial(serialThr) then
    begin
        FreeAndNil(serialThr);
        Exit;
    end;
    serialThr.Start;

end;

procedure SerialPortFrame.sendButtonClick(Sender: TObject);
var
    hexArr: array of char;
    binBufferLen: integer;
begin
    if (serialThr <> nil) and serialThr.isConnected() and (SendMemo.GetTextLen > 0) then
    begin
        if SendEncodingComboBox.ItemIndex = 0 then
            serialThr.SendString(SendMemo.Text)
        else
        begin
            SetLength(hexArr, SendMemo.GetTextLen div 2);
            binBufferLen := HexToBin(PChar(SendMemo.Text), PChar(hexArr),
                SendMemo.GetTextLen div 2);
            serialThr.SendBuffer(PChar(hexArr), binBufferLen);
        end;
    end;
end;

procedure SerialPortFrame.SerialListTimerTimer(Sender: TObject);
var
    serialList: string;
begin
    // 刷新串口列表
    serialList := GetSerialPortNames;
    if (serialList.IsEmpty) then
    begin
        // 只在当前Combox非空时Clear，防止闪烁
        if not (serialComboBox.Items.CommaText.IsEmpty) then
        begin
            serialComboBox.Items.Clear;
        end;
        openButton.Enabled := False;
    end
    else
    begin
        if not (serialComboBox.Items.CommaText.Equals(serialList)) then
        begin
            serialComboBox.Items.CommaText := serialList;
            serialComboBox.ItemIndex := 0;
        end;
        openButton.Enabled := True;
    end;
    // 设置按钮状态
    if (serialThr <> nil) and serialThr.isConnected() then
    begin
        openButton.Enabled := False;
        sendButton.Enabled := True;
        closeButton.Enabled := True;
    end
    else
    begin
        sendButton.Enabled := False;
        closeButton.Enabled := False;
    end;
end;

procedure SerialPortFrame.SerialSendTimerTimer(Sender: TObject);
begin
    sendButtonClick(Sender);
end;

procedure SerialPortFrame.TimerCheckBoxChange(Sender: TObject);
begin
    if (Sender is TCheckBox) then
    begin
        if (Sender as TCheckBox).Checked then
        begin
            SerialSendTimer.Enabled := True;
        end
        else
        begin
            SerialSendTimer.Enabled := False;
        end;
    end;
end;

procedure SerialPortFrame.TimerSpinEditChange(Sender: TObject);
begin
    SerialSendTimer.Interval := TimerSpinEdit.Value;
end;


procedure SerialPortFrame.OnSerialClose;
begin
    closeButton.Enabled := False;
    openButton.Enabled := True;
    serialComboBox.Enabled := True;
end;

procedure SerialPortFrame.processReceivedSerialData(Data: string);
var
    hexArr: array of char;
    hexResult: string;
    i: integer;
begin
    RecvMemo.SelStart := Length(RecvMemo.Text);
    if RecvEncodingComboBox.ItemIndex = 0 then
    begin
        { TODO -omycai : 将各类换行符换成LineBreak }
        RecvMemo.SelText := Data;
    end
    else
    begin
        hexResult := '';
        if RecvMemo.GetTextLen() > 0 then
            hexResult += ':';
        SetLength(hexArr, Data.Length * 2);
        BinToHex(Pointer(Data), PChar(hexArr), Data.Length);
        for i := 0 to High(hexArr) div 2 do
        begin
            hexResult := hexResult + hexArr[i * 2] + hexArr[i * 2 + 1];
            if i * 2 + 1 < High(hexArr) - 1 then
                hexResult := hexResult + ':';
        end;
        RecvMemo.SelText := ansistring(hexResult);
    end;
end;

procedure SerialPortFrame.showWarnBox(message: string);
var
    box: TForm;
begin
    box := CreateMessageDialog(message, mtWarning, [mbClose]);
    box.Position := poOwnerFormCenter;
    box.ShowModal;
end;

function SerialPortFrame.ConfigureSerial(serial: SerialThread): boolean;
var
    baudRate: integer;
    databit: integer;
    paritybit: char;
    stopbit: integer;
begin
    if TryStrToInt(baudrateComboBox.Text, baudRate) then
        baudrate := StrToInt(baudrateComboBox.Text)
    else
    begin
        showWarnBox('波特率参数错误');
        Exit(False);
    end;

    databit := StrToInt(databitComboBox.Text);

    case (paritybitComboBox.Text) of
        '无': paritybit := 'N';
        '奇校验': paritybit := 'O';
        '偶校验': paritybit := 'E';
        else
            paritybit := 'N';
    end;

    case (stopbitComboBox.Text) of
        '1': stopbit := SB1;
        '1.5': stopbit := SB1andHalf;
        '2': stopbit := SB2;
        //else
        //  stopbit := SB1;
    end;
    serialThr.ConfigureSerial(baudRate, databit, paritybit, stopbit, False, False);
    Exit(True);
end;

procedure SerialPortFrame.OnSerialConnected;
begin
    serialComboBox.Enabled := False;
    openButton.Enabled := False;
    closeButton.Enabled := True;
    ConfigureSerial(serialThr);
end;

procedure SerialPortFrame.OnSerialConnectedFailed;
begin
    showWarnBox('串口打开失败');
    openButton.Enabled := True;
    closeButton.Enabled := False;
end;

constructor SerialPortFrame.Create(TheOwner: TComponent);
begin
    inherited Create(TheOwner);
    // 接收到\n即换行
    RecvMemo.Lines.TextLineBreakStyle := tlbsLF;
end;

end.
