import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '/main_page/calendar/Discount.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DiscountDetailPage extends StatefulWidget {
  final Discount discount;

  DiscountDetailPage({required this.discount});

  @override
  _DiscountDetailPageState createState() => _DiscountDetailPageState();
}

class _DiscountDetailPageState extends State<DiscountDetailPage> {
  late TextEditingController nameController;
  late TextEditingController productNameController;
  late TextEditingController descriptionController;
  late DateTime? startTime;
  late dynamic endTime;
  late String quantity;
  late Color color;
  late bool status;

  final List<String> _quantityOptions = [
    '0',
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '10',
    'Sufficient stock'
  ];

  final Map<String, Color> _colorOptions = {
    'Red': Colors.red,
    'Blue': Colors.blue,
    'Green': Colors.green,
    'Yellow': Colors.yellow,
    'Orange': Colors.orange,
    'Purple': Colors.purple,
    'Pink': Colors.pink,
  };

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.discount.merchantName);
    productNameController = TextEditingController(text: widget.discount.productName);
    descriptionController = TextEditingController(text: widget.discount.description);
    startTime = widget.discount.startTime;
    endTime = widget.discount.endTime;
    quantity = widget.discount.quantity;
    color = widget.discount.color;
    status = widget.discount.status;
  }

  void _showEditModal() {
    // Create a separate flag for the color within the modal window
    Color localColor = color;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              return SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(labelText: 'Merchant Name'),
                    ),
                    TextField(
                      controller: productNameController,
                      decoration: InputDecoration(labelText: 'Product Name'),
                    ),
                    TextField(
                      controller: descriptionController,
                      decoration: InputDecoration(labelText: 'Discount Description'),
                    ),
                    ListTile(
                      title: Text('Start Date: ${startTime != null ? DateFormat('yyyy-MM-dd').format(startTime!) : '未选择'}'),
                      trailing: Icon(Icons.calendar_today),
                      onTap: () => _selectStartDate(),
                    ),
                    ListTile(
                      title: Text('End Date: ${endTime is DateTime ? DateFormat('yyyy-MM-dd').format(endTime) : endTime.toString()}'),
                      trailing: Icon(Icons.calendar_today),
                      onTap: () => _selectEndDate(context, false),
                    ),
                    DropdownButtonFormField<String>(
                      value: quantity,
                      items: _quantityOptions.map((String quantity) {
                        return DropdownMenuItem<String>(
                          value: quantity,
                          child: Text(quantity),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setModalState(() {
                          quantity = newValue!;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Availability',
                        labelStyle: TextStyle(
                          fontSize: 22,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    DropdownButtonFormField<String>(
                      value: localColor == null ? null : _colorOptions.entries
                          .firstWhere((entry) => entry.value == localColor, orElse: () => _colorOptions.entries.first)
                          .key,
                      items: _colorOptions.entries.map((MapEntry<String, Color> entry) {
                        return DropdownMenuItem<String>(
                          value: entry.key,
                          child: Container(
                            width: 290,
                            height: 50,
                            decoration: BoxDecoration(
                              color: entry.value,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,

                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setModalState(() {
                          localColor = _colorOptions[newValue]!;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Chooes color on calendar',
                        labelStyle: TextStyle(
                          fontSize: 22,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    SwitchListTile(
                      title: Text('Status'),
                      value: status,
                      onChanged: (bool value) {
                        setModalState(() {
                          status = value;
                        });
                      },
                    ),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          color = localColor;
                        });
                        _updateFirestore();
                      },
                      child: Text('Update'),
                    ),
                  ],
                ),
              );
            }
        );
      },
    );
  }




  void _updateFirestore() {


    String userId = FirebaseAuth.instance.currentUser?.uid ?? '';


    if (userId.isEmpty) {
      print('No user logged in or unable to retrieve user ID.');
      return;
    }



    var updatedEndTime;
    if (endTime is DateTime) {
      updatedEndTime = Timestamp.fromDate(endTime);
    } else if (endTime is String) {
      updatedEndTime = endTime;
    } else {
      updatedEndTime = null;
    }


    FirebaseFirestore.instance
        .collection('users')
        .doc(userId)  // Use the ID of the currently logged in user
        .collection('discounts')
        .doc(widget.discount.documentId)
        .update({
      'merchantName': nameController.text.trim(),
      'productName': productNameController.text.trim(),
      'description': descriptionController.text.trim(),
      'startTime': startTime != null ? Timestamp.fromDate(startTime!) : null,
      'endTime': updatedEndTime,
      'quantity': quantity,
      'color': color.value.toRadixString(16),
      'status': status
    }).then((_) {
      Navigator.pop(context);
    }).catchError((error) {

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Update Failure'),
            content: Text('Unable to update discount：${error.toString()}'),
            actions: <Widget>[
              TextButton(
                child: Text('ok'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    });
  }


  void _selectStartDate() async {

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: startTime ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != startTime) {
      setState(() {
        startTime = picked;
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context, bool isStartTime) async {
    // A dialog box pops up allowing the user to choose between date of use or "Subject to availability"
    final bool useAvailability = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Choose end time'),
        content: Text('Do you want to set a specific date or use "Subject to availability"? '),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('specific date'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Subject to availability'),
          ),
        ],
      ),
    ) ??
        false;

    if (useAvailability) {
      setState(() {
        endTime = 'Subject to availability';
      });
      return;
    }

    // If the user selects a specific date, show the date picker
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStartTime) {
          startTime = picked;
        } else {
          endTime = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Discount Details'),
        actions: [

        Container(
          margin: EdgeInsets.only(right: 20),
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        IconButton(
          icon: Icon(Icons.edit),
          onPressed: () => _showEditModal(),
        ),
        ],
      ),

      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text("Merchant Name: ${widget.discount.merchantName}", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text("Product Name: ${widget.discount.productName}", style: TextStyle(fontSize: 16)),
            Text("Description: ${widget.discount.description}", style: TextStyle(fontSize: 16)),
            Text("Quantity: ${widget.discount.quantity}", style: TextStyle(fontSize: 16)),
            Text("Start Time: ${startTime != null ? DateFormat('yyyy-MM-dd').format(startTime!) : 'Not selected'}", style: TextStyle(fontSize: 16)),
            Text("End Time: ${endTime is DateTime ? DateFormat('yyyy-MM-dd').format(endTime) : endTime.toString()}", style: TextStyle(fontSize: 16)),
            Text("Status: ${status ? 'Active' : 'Inactive'}", style: TextStyle(fontSize: 16)),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _showEditModal,
              child: Text('Edit Discount'),
            )
          ],
        ),
      ),
    );
  }
}
