import 'package:bgn/distribusi/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'draft_store.dart';

class MyHomePageMyWidget extends StatefulWidget {
  const MyHomePageMyWidget({super.key});

  @override
  State<MyHomePageMyWidget> createState() => _MyHomePageMyWidgetState();
}

class _MyHomePageMyWidgetState extends State<MyHomePageMyWidget> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController accessCodeController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  bool _isVisible = false;
  bool rememberMe = false;

  @override
  void dispose() {
    accessCodeController.dispose();
    emailController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = emailController.text.trim();
    final password = accessCodeController.text;

    if (email.isEmpty || password.isEmpty) return;

    final auth = context.read<AuthProvider>();
    final ok = await auth.login(email, password);

    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(auth.loginError ?? "Login gagal"),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final role = auth.currentRole;
    if (role == 'asisten_lapangan') {
      auth.switchRole('aslab');
    } else if (role == 'supplier') {
      DraftStore.loggedInUser = auth.activeUser.name;
      DraftStore.loggedInRole = 'Supplier';
    } else if (role != 'kepala_sppg' && role != 'aslab') {
      DraftStore.loggedInUser = auth.activeUser.name;
      DraftStore.loggedInRole = 'Petugas SPPG';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 7, 32, 52),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 7, 32, 52),
        title: Row(
          children: [
            Text("SPPG", style: TextStyle(color: const Color.fromARGB(255, 73, 143, 200), fontSize: 18),),
            Padding(padding: EdgeInsets.only(left: 8.0),
              child: 
              Text("Portal", style: TextStyle(color: Colors.white),),
            )
          ],
        ),
      ),
      body: 
      SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children:[ 
              Text("Selamat Datang", style: TextStyle(color: Color.fromARGB(255, 73, 143, 200), fontSize: 25, fontWeight: FontWeight.bold),),
              Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: Text("Masuk ke SPPG sistem", style: TextStyle(color: Colors.white),),
              ),
              SizedBox(
                width: MediaQuery.sizeOf(context).width * 0.9,
                height: MediaQuery.sizeOf(context).height * 0.4,
                child: Card(
                  color: const Color.fromARGB(255, 47, 47, 47),
                  child: Form(
                          key: _formKey,
                          child: 
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
        
                              // email
                              Padding(
                                padding: const EdgeInsets.only(top: 16.0, left: 16.0, right: 16),
                                child: TextFormField(
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                      controller: emailController,
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: const Color.fromARGB(255, 40, 40, 40),
                                        hintText: "Username",
                                        hintStyle: const TextStyle(
                                          color: Color.fromARGB(255, 145, 145, 145),
                                          fontSize: 14,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: const BorderSide(
                                            color: Color.fromARGB(255, 19, 89, 146),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: const BorderSide(
                                            color: Color.fromARGB(255, 19, 89, 146),
                                          ),
                                        ),
                                        prefixIcon: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Icon(
                                            Icons.person,
                                            color: Color.fromARGB(255, 133, 133, 133),
                                          ),
                                        ),
                                      ),
                                    ),
                              ),
        
                              // password
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: TextFormField(
                                  style: const TextStyle(color: Colors.white),
                                  controller: accessCodeController,
                                  obscureText: !_isVisible,
                                  decoration: InputDecoration(
                                    hintText: "password",
                                    hintStyle: const TextStyle(
                                      color: Color.fromARGB(255, 133, 133, 133),
                                      fontSize: 14,
                                    ),
                                    filled: true,
                                    fillColor: const Color.fromARGB(255, 40, 40, 40),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                        color: Color.fromARGB(255, 19, 89, 146),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                        color: Color.fromARGB(255, 19, 89, 146),
                                      ),
                                    ),
                                    suffixIcon: IconButton(
                                      onPressed: () {
                                        setState(() {
                                          _isVisible = !_isVisible;
                                        });
                                      },
                                      icon: Icon(
                                        _isVisible == true
                                            ? Icons.visibility
                                            : Icons.visibility_off,
                                        color: const Color(0xFF2AACEB),
                                      ),
                                    ),
                                    prefixIcon: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Icon(
                                        Icons.lock,
                                        color: Color.fromARGB(255, 133, 133, 133),
                                      ),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Password tidak boleh kosong';
                                    }
                                    return null;
                                  },
                                ),
                              ),
        
                              // ======================== remember me =========================
                              SizedBox(
                                  width: MediaQuery.sizeOf(context).width * 0.85,
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Checkbox(
                                            visualDensity: VisualDensity.compact,
                                            materialTapTargetSize:
                                                MaterialTapTargetSize.shrinkWrap,
                                            value: rememberMe,
                                            activeColor: const Color(0xFF0066FF),
                                            onChanged: (value) {
                                              setState(() {
                                                rememberMe = value ?? false;
                                              });
                                            },
                                          ),
                                          TextButton(
                                            style: TextButton.styleFrom(
                                              padding: EdgeInsets.zero,
                                              minimumSize: Size.zero,
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                rememberMe = !rememberMe;
                                              });
                                            },
                                            child: const Text(
                                              "Remember Me",
                                              style: TextStyle(color: Color.fromARGB(255, 176, 176, 176)),
                                            ),
                                          ),
                                        ],
                                      ),
                                      TextButton(
                                        onPressed: () {},
                                        child: const Text("Lupa Password"),
                                      ),
                                    ],
                                  ),
                                ),
        
                              //======================== Buttons =============================
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 60,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF135B92),
                                          Color(0xFF1A8FCC),
                                        ],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(10),
                                        onTap: () {
                                          if (_formKey.currentState!.validate()) {
                                            _login();
                                          }
                                        },
                                        child: const Center(
                                          child: 
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                "Login",
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Padding(
                                                padding: EdgeInsets.only(left: 10.0),
                                                child: Icon(Icons.skip_next, color: Colors.white),
                                              )
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: SizedBox(
                  width: MediaQuery.sizeOf(context).width * 0.9,
                  child: Card(
                    color: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(
                        color: Color.fromARGB(255, 19, 89, 146),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Color.fromARGB(255, 73, 143, 200),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              "Akses Terbatas untuk personel SPPG dan Supplier terdaftar",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ]
          ),
        ),
      )
    );
  }
}

