import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_database/firebase_database.dart';
import '../sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart';
import 'dart:io';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'dart:math';
import 'dart:typed_data';
import 'package:transparent_image/transparent_image.dart';
import 'package:flutter_neumorphic/flutter_neumorphic.dart';

class Photos extends StatefulWidget {
  String _albumName;

  Photos(String albumName) {
    this._albumName = albumName;
  }

  @override
  _PhotosState createState() => _PhotosState();
}

List<IntSize> _createSizes(int count) {
  Random rnd = new Random();
  return new List.generate(count,
      (i) => new IntSize((rnd.nextInt(500) + 200), rnd.nextInt(800) + 200));
}

class _PhotosState extends State<Photos> {
  final databaseReference =
      FirebaseDatabase.instance.reference().child("$id").child("albums");
  final storageReference =
      FirebaseStorage.instance.ref().child("$id").child("images");

  _PhotosState() : _sizes = _createSizes(_kItemCount).toList();

  static const int _kItemCount = 1000;
  final List<IntSize> _sizes;

  void updateUrl(imageData, imageName) {
    databaseReference
        .child(widget._albumName)
        .child("pictures")
        .update({'link': imageData, "imgName": imageName});
  }

  void createUrl(imageData, imageName) {
    databaseReference
        .child(widget._albumName)
        .child("pictures")
        .push()
        .set({'link': imageData, "imgName": imageName}).whenComplete(() {
      print("Photo created");
    });
  }

  File _image;
  final picker = ImagePicker();

  Future<List> uploadImage(var imageFile) async {
    StorageReference ref = FirebaseStorage.instance
        .ref()
        .child("$id")
        .child("images")
        .child(basename(imageFile.path));
    StorageUploadTask uploadTask =
        ref.putFile(imageFile, StorageMetadata(contentType: 'image/jpeg'));
    final snapshot = await uploadTask.onComplete;
    var downUrl;
    if (snapshot.error == null) {
      downUrl = await snapshot.ref.getDownloadURL();
    } else {
      print(snapshot.error);
      downUrl = null;
    }
    String url = downUrl.toString();
    List returnedList = [url, basename(imageFile.path)];

    return returnedList;
  }

  Future selectImage() async {
    final pickedFile = await picker.getImage(source: ImageSource.gallery);
    _image = File(pickedFile.path);

    var uploadUrl = await uploadImage(_image);
    createUrl(uploadUrl[0], uploadUrl[1]);
  }

  List<String> photoList = List<String>();

  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();

  void _showScaffold(String message) {
    _scaffoldKey.currentState.showSnackBar(SnackBar(
      content: Text(message),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(
          "Photos",
          style: TextStyle(
              fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 25),
        ),
        centerTitle: true,
        backgroundColor: Colors.cyanAccent[400],
        leading: GestureDetector(
            onTap: () {
              Navigator.pop(context);
            },
            child: Icon(
              Icons.arrow_back,
            )),
      ),
      body: Column(
        children: [
          Center(
              child: Container(
                  margin: EdgeInsets.all(8),
                  width: 190,
                  child: Neumorphic(
                      style: NeumorphicStyle(
                          shape: NeumorphicShape.concave,
                          surfaceIntensity: 0.2,
                          depth: 1.5,
                          intensity: 5,
                          lightSource: LightSource.topLeft,
                          color: Colors.grey[200]),
                      child: FlatButton(
                          onPressed: () {
                            selectImage();
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Icon(
                                Icons.add_a_photo,
                                size: 35,
                                color: Colors.pink[400],
                              ),
                              Text(
                                "Add picture",
                                style: TextStyle(
                                    fontFamily: 'BalooBhai', fontSize: 20.0),
                              )
                            ],
                          ))))),
          Flexible(
            child: StreamBuilder(
              stream: databaseReference
                  .child(widget._albumName)
                  .child("pictures")
                  .onValue,
              builder: (context, snap) {
                if (snap.hasData &&
                    !snap.hasError &&
                    snap.data.snapshot.value != null) {
                  Map data = snap.data.snapshot.value;
                  List item = [];

                  data.forEach(
                      (index, data) => item.add({"key": index, ...data}));

                  return new StaggeredGridView.countBuilder(
                    primary: false,
                    itemCount: item.length,
                    crossAxisCount: 4,
                    mainAxisSpacing: 4.0,
                    crossAxisSpacing: 4.0,
                    itemBuilder: (context, index) => InkResponse(
                      child:
                          new _Tile(index, _sizes[index], item[index]["link"]),
                      onLongPress: () {
                        showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                actions: <Widget>[
                                  FlatButton(
                                    child: Icon(Icons.delete),
                                    onPressed: () {
                                      setState(() {
                                        String key = item[index]['key'];
                                        storageReference
                                            .child(item[index]["imgName"])
                                            .delete();
                                        databaseReference
                                            .child(widget._albumName)
                                            .child("pictures")
                                            .child('$key')
                                            .remove();
                                        Navigator.of(context).pop();
                                      });
                                      _showScaffold("Deleted Photo");
                                    },
                                  )
                                ],
                                title: Text("Delete Photo?"),
                              );
                            });
                      },
                    ),
                    staggeredTileBuilder: (index) => new StaggeredTile.fit(2),
                  );
                } else
                  return Text("No Photos");
              },
            ),
          ),
        ],
      ),
    );
  }
}

class IntSize {
  const IntSize(this.width, this.height);

  final int width;
  final int height;
}

class _Tile extends StatelessWidget {
  const _Tile(this.index, this.size, this.imgUrl);

  final IntSize size;
  final int index;
  final String imgUrl;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: new Column(
        children: <Widget>[
          new Stack(
            children: <Widget>[
              //new Center(child: new CircularProgressIndicator()),
              new Center(
                child: new FadeInImage.memoryNetwork(
                  placeholder: kTransparentImage,
                  image: '$imgUrl',
                ),
              ),
            ],
          ),
          new Padding(
            padding: const EdgeInsets.all(4.0),
            child: new Column(
              children: <Widget>[
                new Text(
                  'Image number $index',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                new Text(
                  'Width: ${size.width}',
                  style: const TextStyle(color: Colors.grey),
                ),
                new Text(
                  'Height: ${size.height}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// GridView.builder(
//                     itemCount: item.length,
//                     gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//                       crossAxisCount: 2,
//                       crossAxisSpacing: 10,
//                       mainAxisSpacing: 10,
//                     ),
//                     padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                     itemBuilder: (context, index) {
//                       return GridTile(
//                         child: Text(item[index]["link"]),
//                       );
//                     },
//                   );
