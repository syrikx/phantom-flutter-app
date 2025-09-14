import 'package:flutter/material.dart';
import 'phantom_wallet_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({Key? key}) : super(key: key);

  @override
  WalletScreenState createState() => WalletScreenState();
}

class WalletScreenState extends State<WalletScreen> {
  final PhantomWalletService walletService = PhantomWalletService();
  final TextEditingController messageController = TextEditingController();
  final TextEditingController recipientController = TextEditingController();
  final TextEditingController amountController = TextEditingController();

  bool isConnecting = false;

  @override
  void initState() {
    super.initState();
    messageController.text = 'Hello Phantom!';
    amountController.text = '0.001';
    _restoreConnection();
  }

  @override
  void dispose() {
    messageController.dispose();
    recipientController.dispose();
    amountController.dispose();
    super.dispose();
  }

  Future<void> _restoreConnection() async {
    await walletService.restoreConnection();
    setState(() {});
  }

  Future<void> _handleConnect() async {
    setState(() {
      isConnecting = true;
    });

    try {
      await walletService.connect(provider: 'google');
      _showDialog('성공', '지갑이 연결되었습니다!');
    } catch (error) {
      _showDialog('오류', '연결 실패: $error');
    } finally {
      setState(() {
        isConnecting = false;
      });
    }
  }

  Future<void> _handleDisconnect() async {
    try {
      await walletService.disconnect();
      _showDialog('성공', '지갑 연결이 해제되었습니다!');
      setState(() {});
    } catch (error) {
      _showDialog('오류', '연결 해제 실패: $error');
    }
  }

  Future<void> _handleSignMessage() async {
    if (messageController.text.trim().isEmpty) {
      _showDialog('오류', '메시지를 입력해주세요.');
      return;
    }

    try {
      final signature = await walletService.signMessage(messageController.text);
      _showDialog('서명 성공', '서명: ${signature.substring(0, 20)}...');
    } catch (error) {
      _showDialog('오류', '메시지 서명 실패: $error');
    }
  }

  Future<void> _handleSendTransaction() async {
    if (recipientController.text.trim().isEmpty || amountController.text.trim().isEmpty) {
      _showDialog('오류', '받는 주소와 금액을 입력해주세요.');
      return;
    }

    try {
      final transaction = {
        'type': 'transfer',
        'params': {
          'destination': recipientController.text,
          'amount': (double.parse(amountController.text) * 1000000000).toInt(),
        },
      };

      final signature = await walletService.signAndSendTransaction(transaction);
      _showDialog('전송 성공', '트랜잭션 서명: ${signature.substring(0, 20)}...');
    } catch (error) {
      _showDialog('오류', '트랜잭션 전송 실패: $error');
    }
  }

  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              child: Text('확인'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!walletService.isConnected) {
      return Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Phantom 지갑 테스트 앱',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10),
            Text(
              '지갑을 연결하여 시작하세요',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: isConnecting ? null : _handleConnect,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFab9ff2),
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                isConnecting ? '연결 중...' : 'Google로 지갑 연결',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Phantom 지갑 연결됨',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20),

          Container(
            width: double.infinity,
            padding: EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '지갑 주소:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 5),
                for (String address in walletService.addresses) Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(10),
                  margin: EdgeInsets.only(top: 5),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    '${address.substring(0, 20)}...${address.substring(address.length - 10)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'monospace',
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),

          Container(
            width: double.infinity,
            padding: EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '메시지 서명',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: messageController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: '서명할 메시지 입력',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
                SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _handleSignMessage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFab9ff2),
                      padding: EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      '메시지 서명',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),

          Container(
            width: double.infinity,
            padding: EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SOL 전송 (테스트용)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: recipientController,
                  decoration: InputDecoration(
                    hintText: '받는 주소 입력',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: '전송할 SOL 수량',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
                SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _handleSendTransaction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFab9ff2),
                      padding: EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      '트랜잭션 전송',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _handleDisconnect,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFff6b6b),
                padding: EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                '지갑 연결 해제',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}