// ignore_for_file: unused_local_variable, dead_code, override_on_non_overriding_member

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/drive/v2.dart' as drive2;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/io_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
        apiKey: "AIzaSyAVigLIC9Lecmos33CdB08vNRejJajwYOE",
        authDomain: "filedisplay1.firebaseapp.com",
        projectId: "filedisplay1",
        storageBucket: "filedisplay1.appspot.com",
        messagingSenderId: "199319964939",
        appId: "1:199319964939:web:fcbb8fdf70f6a43d88a60e"),
  );

  runApp(
    MaterialApp(
      home: GoogleDriveTest(),
    ),
  );
}

/*class GoogleHttpClient extends IOClient {  
 Map<String, String> _headers;  
 GoogleHttpClient(this._headers) : super();  
 @override  
 Future<http.StreamedResponse> async; send(http.BaseRequest request) =>  
     super.send(request..headers.addAll(_headers));  
 @override  
 Future<http.Response> head(Object url, {Map<String, String>? headers}) =>  
     super.head(url, headers: headers!..addAll(_headers));  
}  */

class GoogleDriveTest extends StatefulWidget {
  @override
  _GoogleDriveTest createState() => _GoogleDriveTest();
}

class _GoogleDriveTest extends State<GoogleDriveTest> {
  bool _loginStatus = false;
  final googleSignIn = GoogleSignIn.standard(scopes: [
    drive.DriveApi.driveAppdataScope,
    drive.DriveApi.driveFileScope,
  ]);

  @override
  void initState() {
    _loginStatus = googleSignIn.currentUser != null;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: Builder(builder: (BuildContext context) {
      return SafeArea(
        child: Scaffold(
          appBar: AppBar(
            title: Text("Google Drive Test"),
          ),
          body: _createBody(context),
        ),
      );
    }));
  }

  Widget _createBody(BuildContext context) {
    final signIn = ElevatedButton(
      onPressed: () {
        _signIn();
      },
      child: Text("Sing in"),
    );
    final signOut = ElevatedButton(
      onPressed: () {
        _signOut();
      },
      child: Text("Sing out"),
    );
    final uploadToHidden = ElevatedButton(
      onPressed: () {
        _uploadToHidden();
      },
      child: Text("Upload to app folder (hidden)"),
    );
    final uploadToNormal = ElevatedButton(
      onPressed: () {
        _uploadToNormal();
      },
      child: Text("Upload to internship folder"),
    );
    final showList = ElevatedButton(
      onPressed: () {
        _showList();
      },
      child: Text("files in google drive"),
    );
    final displayFileContent = ElevatedButton(
      onPressed: () {
        _downloadFile();
      },
      child: Text("display file content"),
    );
    return Column(
      children: [
        Center(child: Text("Sign in status: ${_loginStatus ? "In" : "Out"}")),
        Center(child: signIn),
        Center(child: signOut),
        Divider(),
        Center(child: uploadToHidden),
        Center(child: uploadToNormal),
        Center(child: showList),
        // Center(child: listFilesInMyFolder),
        Center(
            child: _createButton(
                "Files in internship folder", _showFilesInMyFolder)),
        // Center(child: _createButton("file content is: ", _downloadFile())),
        Center(child: displayFileContent),
      ],
    );
  }

  Future<void> _signIn() async {
    final googleUser = await googleSignIn.signIn();

    try {
      if (googleUser != null) {
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        final UserCredential loginUser =
            await FirebaseAuth.instance.signInWithCredential(credential);

        assert(loginUser.user?.uid == FirebaseAuth.instance.currentUser?.uid);
        print("Sign in");
        setState(() {
          _loginStatus = true;
        });
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    await googleSignIn.signOut();
    setState(() {
      _loginStatus = false;
    });
    print("Sign out");
  }

  Future<drive.DriveApi?> _getDriveApi() async {
    final googleUser = await googleSignIn.signIn();
    final headers = await googleUser?.authHeaders;
    if (headers == null) {
      return null;
    }

    final client = GoogleAuthClient(headers);
    final driveApi = drive.DriveApi(client);
    return driveApi;
  }

  Future<void> _uploadToHidden() async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) {
        return;
      }
      // Not allow a user to do something else
      showGeneralDialog(
        context: context,
        barrierDismissible: false,
        transitionDuration: Duration(seconds: 2),
        barrierColor: Colors.black.withOpacity(0.5),
        pageBuilder: (context, animation, secondaryAnimation) => Center(
          child: CircularProgressIndicator(),
        ),
      );
      // Create data here instead of loading a file
      final contents = "This is a sample file";
      final Stream<List<int>> mediaStream =
          Future.value(contents.codeUnits).asStream().asBroadcastStream();
      var media = new drive.Media(mediaStream, contents.length);

      // Set up File info
      var driveFile = new drive.File();
      final timestamp = DateFormat("yyyy-MM-dd-hhmmss").format(DateTime.now());
      driveFile.name = "sample file-$timestamp.txt";
      driveFile.modifiedTime = DateTime.now().toUtc();
      driveFile.parents = ["appDataFolder"];

      // Upload
      final response =
          await driveApi.files.create(driveFile, uploadMedia: media);
      print("response: $response");

      // simulate a slow process
      await Future.delayed(Duration(seconds: 2));
    } finally {
      // Remove a dialog
      Navigator.pop(context);
    }
  }

  Future<String?> _getFolderId(drive.DriveApi driveApi) async {
    final mimeType = "application/vnd.google-apps.folder";
    String folderName = "Flutter-sample-by-tf";

    try {
      final found = await driveApi.files.list(
        q: "mimeType = '$mimeType' and name = '$folderName'",
        $fields: "files(id, name)",
      );
      final files = found.files;
      if (files == null) {
        return null;
      }

      if (files.isNotEmpty) {
        return files.first.id;
      }

      // Create a folder
      var folder = new drive.File();
      folder.name = folderName;
      folder.mimeType = mimeType;
      final folderCreation = await driveApi.files.create(folder);
      print("Folder ID: ${folderCreation.id}");

      return folderCreation.id;
    } catch (e) {
      print(e);
      // I/flutter ( 6132): DetailedApiRequestError(status: 403, message: The granted scopes do not give access to all of the requested spaces.)
      return null;
    }
  }

  Future<void> _uploadToNormal() async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) {
        return;
      }
      // Not allow a user to do something else
      showGeneralDialog(
        context: context,
        barrierDismissible: false,
        transitionDuration: Duration(seconds: 2),
        barrierColor: Colors.black.withOpacity(0.5),
        pageBuilder: (context, animation, secondaryAnimation) => Center(
          child: CircularProgressIndicator(),
        ),
      );

      final folderId = await _getFolderId(driveApi);
      if (folderId == null) {
        return;
      }

      // Create data here instead of loading a file
      final contents = "this is a sample file";
      final Stream<List<int>> mediaStream =
          Future.value(contents.codeUnits).asStream().asBroadcastStream();
      var media = new drive.Media(mediaStream, contents.length);

      // Set up File info
      var driveFile = new drive.File();
      final timestamp = DateFormat("yyyy-MM-dd-hhmmss").format(DateTime.now());
      driveFile.name = "sample file-$timestamp.txt";
      driveFile.modifiedTime = DateTime.now().toUtc();
      driveFile.parents = [folderId];

      // Upload
      final response =
          await driveApi.files.create(driveFile, uploadMedia: media);
      print("response: $response");

      // simulate a slow process
      await Future.delayed(Duration(seconds: 2));
    } finally {
      // Remove a dialog
      Navigator.pop(context);
    }
  }

  Future<void> _showList() async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) {
      return;
    }

    final fileList = await driveApi.files.list(
      spaces: 'drive',
      $fields: 'files(id, name, modifiedTime)',
    );
    final files = fileList.files;
    if (files == null) {
      return null;
    }

    final alert = AlertDialog(
      title: Text("Item List"),
      content: SingleChildScrollView(
        child: ListBody(
          children: files.map((e) => Text(e.name ?? "no-name")).toList(),
        ),
      ),
    );

    return showDialog(
      context: context,
      builder: (BuildContext context) => alert,
    );
  }

  Future<drive.FileList> _showFilesInMyFolder(drive.DriveApi driveApi) async {
    final folderId = await _getMyFolderId(driveApi, "internship");
    return driveApi.files.list(
      spaces: 'drive',
      q: "'$folderId' in parents",
    );
  }

  Future<String?> _getMyFolderId(
    drive.DriveApi driveApi,
    String folderName,
  ) async {
    try {
      String _folderType = "application/vnd.google-apps.folder";
      final found = await driveApi.files.list(
        q: "mimeType = '$_folderType' and name = '$folderName'",
        $fields: "files(id, name)",
      );
      final files = found.files;
      if (files == null) {
        return null;
      }

      if (files.isNotEmpty) {
        return files.first.id;
      }
    } catch (e) {
      print(e);
    }
    return null;
  }

  Widget _createButton(String title, Function(drive.DriveApi driveApi) query) {
    return ElevatedButton(
      onPressed: () async {
        final driveApi = await _getDriveApi();
        if (driveApi == null) {
          return;
        }

        final fileList = await query(driveApi);
        final files = fileList.files;
        if (files == null) {
          return print("Data not found");
        }
        await _showList2(files);
      },
      child: Text(title),
    );
  }

  Future<void> _showList2(List<drive.File> files) {
    const _folderType = "application/vnd.google-apps.folder";
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("List"),
          content: Container(
            width: MediaQuery.of(context).size.height - 50,
            height: MediaQuery.of(context).size.height,
            child: ListView.builder(
              itemCount: files.length,
              itemBuilder: (context, index) {
                final isFolder = files[index].mimeType == _folderType;

                return ListTile(
                  leading: Icon(isFolder
                      ? Icons.folder
                      : Icons.insert_drive_file_outlined),
                  title: Text(files[index].name ?? ""),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _downloadFile() async {
    // final folderId = await _getMyFolderId(driveApi, "internship");

    String fileID = '1PQLkN3vC_ew-1Otedw5YY_bYZ8rEHq9b';

    // GET https;//www.googleapis.com/drive/v2/files/fileId
    // ga.FileList files = await driveApi.files.list(q: "'root' in parents");

    // ga.Media response = await driveApi.files.get(fileID, downloadOptions: ga.DownloadOptions.FullMedia);
    /*Object response = await driveApi.files
      .get(fileID, downloadOptions: DownloadOptions.fullMedia);*/
    final driveApi = await _getDriveApi();
    if (driveApi == null) {
      return;
    }
    /*
    Map<String, dynamic> response = await driveApi.files.get(fileID,
        downloadOptions: drive.DownloadOptions()) as Map<String, dynamic>;
        */

    drive.Media response = await driveApi.files.get(fileID,
        downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;

    print("OK1");
    print(response.toString());
    print("OK2");

    /*
    List<int> dataStore = [];
    response.stream.listen((data) {
      print("OK3");
      print("DataReceived: ${data.length}");
      print("OK4");
      dataStore.insertAll(dataStore.length, data);
    }, onDone: () async {
      print("OK5");
      Directory tempDir =
          await getTemporaryDirectory(); //Get temp folder using Path Provider
      print("OK6");
      String tempPath = tempDir.path; //Get path to that location
      print("OK7");
      File file = File('$tempPath/test'); //Create a dummy file
      print("OK8");
      await file.writeAsBytes(
          dataStore); //Write to that file from the datastore you created from the Media stream
      print("OK9");
      String content = file.readAsStringSync(); // Read String from the file
      print("OK10");
      print(content); //Finally you have your text
      print("Task Done");
    }, onError: (error) {
      print("Some Error");
    });
    */
  }
}

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final _client = new http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}
