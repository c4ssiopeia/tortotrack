import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'weight_table.dart';

class TableScreen extends StatefulWidget {
  const TableScreen({super.key});

  @override
  State<TableScreen> createState() => _TableScreenWithState();
}

class _TableScreenWithState extends State<TableScreen> {
  String _text = "99.05";
  // late double _inputWeight;

  TextEditingController inputController = TextEditingController();

  @override
  void initState() {
    inputController = TextEditingController();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(_text),
        // child: Container(_inputWeight),
      ),
      // this is the button that will open the AlertDialog where the userinput is handled
      floatingActionButton: FloatingActionButton(
          onPressed: () => _dialogBuilder(context),
          child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _dialogBuilder(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Track your today's weight"),
          actionsAlignment: MainAxisAlignment.center,
          actions: <Widget>[
            InputTile(controller: inputController),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextButton(
                  style: TextButton.styleFrom(
                    textStyle: Theme.of(context).textTheme.labelLarge,
                  ),
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    textStyle: Theme.of(context).textTheme.labelLarge,
                  ),
                  child: const Text('Submit'),
                  onPressed: () {
                    setState(() {
                      _text = inputController.text;
                    });
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class InputTile extends StatelessWidget {
  const InputTile({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: EdgeInsets.symmetric(horizontal: 30.0, vertical: 20.0),
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'Enter your weight today',
          ),
        ),
    );
  }
}

// double correctWeightToDouble(String weightInput) {
//   try {
//     return double.parse(weightInput.replaceAll(",", "."));
//   } catch (e) {
//     print("You didn't input a number. Please input Numbers like '100,00' or '98.95' or '80'!");
//     exit(1);
//   }
// }