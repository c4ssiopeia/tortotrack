import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'weight_table.dart';

class TableScreen extends StatefulWidget {
  const TableScreen({super.key});

  @override
  State<TableScreen> createState() => _TableScreenWithState();
}

class _TableScreenWithState extends State<TableScreen> {
  final _formKey = GlobalKey<FormState>();
  final _weightInputController = TextEditingController();
  var weightInput = "start";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(weightInput),
      ),
      // this is the button that will open the AlertDialog where the userinput is handled
      floatingActionButton: FloatingActionButton(
          onPressed: () => _dialogBuilder(context),
          child: const Icon(Icons.add),
      ),
    );
  }

  void _submitForm(){
    // validation is done in _dialogBuilder because otherwise the Dialog would close even if not return null
    final doubleWeightInput = double.parse(_weightInputController.text.replaceAll(',', '.')); // us this later for database input
    setState(() {
      weightInput = doubleWeightInput.toString();
    });
      // without setState, you have to write the things, you wanna do with weightInput here!
  }

  Widget _inputTileWidget(BuildContext context) {
    return Padding(
        padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 20.0),
        child: Form(
          key: _formKey,
          child: TextFormField(
            controller: _weightInputController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Enter your weight today',
              errorMaxLines: 3,
            ),
            validator: (value){
              if (value == null || value.isEmpty) {
                return "Please enter a weight.";
              }
              final doubleValue = double.tryParse(value.replaceAll(',', '.'));
              if (doubleValue == null){
                return "Please input a number like '100.00', '98,95' or '80'.";
              }
              return null;
            },
          ),
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
            _inputTileWidget(context),
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
                    if (_formKey.currentState!.validate()){
                      _submitForm();
                      Navigator.of(context).pop();
                    }
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