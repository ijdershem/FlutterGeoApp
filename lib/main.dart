import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/rendering.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'map.dart';
import 'package:flutter/rendering.dart';

void main() async {
  // debugPaintSizeEnabled = true;
  WidgetsFlutterBinding.ensureInitialized();
  GoogleSignIn gSignIn = GoogleSignIn();
  bool userAuthenticated = await gSignIn.isSignedIn();
  FirebaseUser user = null;

  if(userAuthenticated) {
    FirebaseAuth _auth = FirebaseAuth.instance;
    user = await _auth.currentUser();
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: WelcomeUserWidget(user, gSignIn)
      ));
  } else {
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: LoginPageWidget(),
      ));
  }
  
}

class LoginPageWidget extends StatefulWidget {

   @override
   LoginPageWidgetState createState() => LoginPageWidgetState();
}

class LoginPageWidgetState extends State<LoginPageWidget> {
  
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool isUserSignedIn = false;

  @override
  void initState() {
    super.initState();
    checkIfUserIsSignedIn();
  }

  void checkIfUserIsSignedIn() async {
    var userSignedIn = await _googleSignIn.isSignedIn();
    
    setState(() {
        isUserSignedIn = userSignedIn;
    });

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: EdgeInsets.all(50),
        child: Align(
          alignment: Alignment.center,
          child: FlatButton(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            onPressed: () {
              onGoogleSignIn(context);
            },
            color: isUserSignedIn ? Colors.green : Colors.blueAccent,
            child: Padding(
              padding: EdgeInsets.all(10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Icon(Icons.account_circle, color: Colors.white),
                  SizedBox(width: 10),
                  Text(
                    isUserSignedIn ? 'You\'re logged in with Google' : 'Login with Google', 
                    style: TextStyle(color: Colors.white))
                ],
              )
            )
          )
        )
      )
    );
  }

  Future<FirebaseUser> _handleSignIn() async {
    FirebaseUser user;
    bool userSignedIn = await _googleSignIn.isSignedIn();  
    
    setState(() {
      isUserSignedIn = userSignedIn;
    });

    if (isUserSignedIn) {
      user = await _auth.currentUser();
    }
    else {
      final GoogleSignInAccount googleUser = await _googleSignIn.signIn();
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.getCredential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      user = (await _auth.signInWithCredential(credential)).user;
      userSignedIn = await _googleSignIn.isSignedIn();
      setState(() {
        isUserSignedIn = userSignedIn;
      });
    }
    return user;
  }

  void onGoogleSignIn(BuildContext context) async {
    FirebaseUser user = await _handleSignIn();
    var userSignedIn = await Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (BuildContext context) =>
                      WelcomeUserWidget(user, _googleSignIn)),
            );
  }
}

class WelcomeUserWidget extends StatelessWidget {

  GoogleSignIn _googleSignIn;
  FirebaseUser _user;
  DocumentReference _userDocument; 
  final Firestore databaseReference = Firestore.instance;

  WelcomeUserWidget(FirebaseUser user, GoogleSignIn signIn) {
    _user = user;
    _googleSignIn = signIn;
    getUserFirestoreData();
  }

  void onMapButtonPressed(BuildContext context) async {
    if(this._userDocument == null) {
      this._userDocument = await getUserFirestoreData();
    } 
    var navToMap = Navigator.push(
        context,
        MaterialPageRoute(
            builder: (BuildContext context) =>
              MapWidget(this.databaseReference, this._userDocument, this._user)), 
        );
    
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: Container(
        color: Colors.white,
        padding: EdgeInsets.all(50),
        child: Align(
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              ClipOval(
                child: Image.network(
                  _user.photoUrl,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover
                )
              ),
              SizedBox(height: 20),
              Text('Welcome,', textAlign: TextAlign.center),
              Text(_user.displayName, textAlign: TextAlign.center, 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 25)),
              SizedBox(height: 20),
              FlatButton(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                onPressed: () {
                  _googleSignIn.signOut();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (BuildContext context) =>
                            LoginPageWidget()),
                  );
                  // Navigator.pop(context, false);
                },
                color: Colors.redAccent,
                child: Padding(
                  padding: EdgeInsets.all(10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Icon(Icons.exit_to_app, color: Colors.white),
                      SizedBox(width: 10),
                      Text('Log out of Google', style: TextStyle(color: Colors.white))
                    ],
                  )
                )
              ),
              FlatButton( //Button for taking user to Map Widget (map.dart)
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                onPressed: () {
                  onMapButtonPressed(context);
                },
                color: Colors.blueAccent,
                child: Padding(
                  padding: EdgeInsets.all(10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Icon(Icons.account_circle, color: Colors.white),
                      SizedBox(width: 10),
                      Text('Map', style: TextStyle(color: Colors.white))
                    ],
                  )
                )
              )
            ],
          )
        )
      )
    );
  }

  // Returns a reference to the document from the user_data Firestore corresponding to the authenticated user's id.
  // If a document does not yet exist for the user (i.e. This is the user's first time logging in), one will be created.
  Future<DocumentReference> getUserFirestoreData() async {  
    String uid =  _user.uid;
    Firestore db = this.databaseReference;
    CollectionReference userDataCollection = db.collection('/user_data');

    DocumentReference userData = await checkIfUserDocExists(userDataCollection, uid);

    if(userData != null) {
      this._userDocument = userData;
      return userData; 
    } else {
      print('Creating document for new user...');
      userData = await createUserDoc(userDataCollection, uid);

    }
    return userData;
  }

  // Check if the authenticated user has a Firestore document in the user_data collection and return its reference.
  // Otherwise return null.
  checkIfUserDocExists(CollectionReference userDataCollection, String uid) async {
    var doc = await userDataCollection.getDocuments(); //TODO need to try and catch if fails 

    for (var id in doc.documents) {
      if (id.documentID == uid) { // return user document if user id exists in user_data collection
        var userDoc = userDataCollection.document(uid);
        return userDoc;
      }
    }
    return null; 
  }

  // Create a new Firestore document in the user_data collection for the provided given user id and return its reference.
  createUserDoc(CollectionReference userDataCollection, String uid) async {
    DocumentReference userData = userDataCollection.document(uid);
    await userData.setData({'uid': uid}).then((_) {
      print('New user added with uid: ' + uid);
      return userData;
    });
  }
}



