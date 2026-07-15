import 'dart:async';
import 'package:flutter/material.dart';
import '../services/status_service.dart';

class ProcessingBanner extends StatefulWidget {
  const ProcessingBanner({Key? key}) : super(key: key);

  @override
  State<ProcessingBanner> createState() => _ProcessingBannerState();
}

class _ProcessingBannerState extends State<ProcessingBanner> {
  final StatusService _statusService = StatusService();
  Timer? _timer;
  List<dynamic> _statuses = [];

  @override
  void initState() {
    super.initState();
    _fetchStatus();
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _fetchStatus();
    });
  }

  Future<void> _fetchStatus() async {
    final statuses = await _statusService.fetchProcessingStatuses();
    if (mounted) {
      setState(() {
        _statuses = statuses;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_statuses.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      color: Colors.blue.shade50,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text(
                'Sedang Memproses dari WAHA...',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._statuses.map((status) {
            final filename = status['filename'] ?? 'Unknown';
            final text = status['status'] ?? '';
            final isError = text.contains('❌');
            final isSuccess = text.contains('✅');
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isError ? Icons.error : (isSuccess ? Icons.check_circle : Icons.sync),
                    size: 16,
                    color: isError ? Colors.red : (isSuccess ? Colors.green : Colors.blue),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '$filename: $text',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
