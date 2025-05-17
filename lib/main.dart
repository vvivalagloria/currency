import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(CurrencyApp());

class CurrencyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Currency Converter',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: CurrencyConverterPage(),
    );
  }
}

class CurrencyConverterPage extends StatefulWidget {
  @override
  _CurrencyConverterPageState createState() => _CurrencyConverterPageState();
}

class _CurrencyConverterPageState extends State<CurrencyConverterPage> {
  static const _apiKey = 'dd08d742cc38b5564871170b820693c0';
  static const _liveEndpoint = 'https://api.currencylayer.com/live';

  Map<String, double> _rates = {};
  List<String> _currencies = [];
  String? _fromCurrency;
  String? _toCurrency;
  final TextEditingController _amountController = TextEditingController(text: '1');
  String? _result;
  String? _error;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchLiveRates();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _fetchLiveRates() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse('$_liveEndpoint?access_key=$_apiKey');
      final resp = await http.get(uri);
      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}');
      }

      final body = json.decode(resp.body) as Map<String, dynamic>;
      if (body['success'] != true) {
        throw Exception(body['error']?['info'] ?? 'Unknown error');
      }

      final source = body['source'] as String;
      final quotes = body['quotes'] as Map<String, dynamic>;
      final rates = <String, double>{};

      quotes.forEach((k, v) {
        final code = k.replaceFirst(source, '');
        rates[code] = (v as num).toDouble();
      });

      setState(() {
        _rates = rates;
        _currencies = rates.keys.toList()..sort();
        _fromCurrency ??= _currencies.first;
        _toCurrency   ??= (_currencies.length > 1 ? _currencies[1] : _currencies.first);
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _convert() {
    if (_rates.isEmpty || _fromCurrency == null || _toCurrency == null || _amountController.text.isEmpty) return;

    final amount = double.tryParse(_amountController.text);
    if (amount == null) {
      setState(() => _error = 'Invalid amount');
      return;
    }

    final rateFrom = _rates[_fromCurrency!]!;
    final rateTo   = _rates[_toCurrency!]!;
    final result   = amount / rateFrom * rateTo;

    setState(() {
      _result = result.toStringAsFixed(4);
      _error  = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Currency Converter')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),

            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _fromCurrency,
                    items: _currencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setState(() => _fromCurrency = v),
                    decoration: const InputDecoration(labelText: 'From'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _toCurrency,
                    items: _currencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setState(() => _toCurrency = v),
                    decoration: const InputDecoration(labelText: 'To'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount'),
            ),

            const SizedBox(height: 24),
            ElevatedButton(onPressed: _convert, child: const Text('Convert')),

            if (_result != null) ...[
              const SizedBox(height: 16),
              Text(
                'Result: $_result $_toCurrency',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],

            const Spacer(),
            ElevatedButton.icon(
              onPressed: () { _fetchLiveRates(); },
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Rates'),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
