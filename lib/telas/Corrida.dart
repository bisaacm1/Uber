import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uber/model/Usuario.dart';
import 'package:uber/util/StatusRequisicao.dart';
import 'package:uber/util/UsuarioFirebase.dart';

class Corrida extends StatefulWidget {
  String idRequisicao;
  Corrida(this.idRequisicao);

  @override
  _CorridaState createState() => _CorridaState();
}

class _CorridaState extends State<Corrida> {
  Map<String, dynamic> _dadosRequisicao;
//Controles para exibição de tela
  String _textoBotao = 'Aceitar corrida';
  Color _corBotao = Color(0xff1ebbd8).withOpacity(0.9);
  Function _funcaoBotao;
  Position _localMotorista;

  _alterarBotaoPrincipal(String texto, Color cor, Function funcao) {
    setState(() {
      _textoBotao = texto;
      _corBotao = cor;
      _funcaoBotao = funcao;
    });
  }

  Completer<GoogleMapController> _controller = Completer();
  Set<Marker> _marcadores = {};
  CameraPosition _posicaoCamera = CameraPosition(
    target: LatLng(-23.563999, -46.653256),
  );

  _onMapCreated(GoogleMapController controller) {
    _controller.complete(controller);
  }

  _exibirMarcadorMotorista(Position local) async {
    double pixelRatio = MediaQuery.of(context).devicePixelRatio;

    BitmapDescriptor.fromAssetImage(
      ImageConfiguration(devicePixelRatio: pixelRatio),
      'images/motorista.png',
    ).then((BitmapDescriptor icone) {
      Marker marcadorPassageiro = Marker(
        markerId: MarkerId('marcador-motorista'),
        position: LatLng(local.latitude, local.longitude),
        infoWindow: InfoWindow(title: 'Meu local'),
        icon: icone,
      );

      setState(() {
        _marcadores.add(marcadorPassageiro);
      });
    });
  }

  _recuperaUltimaLocalizacaoConhecida() async {
    Position position = await Geolocator()
        .getLastKnownPosition(desiredAccuracy: LocationAccuracy.high);

    setState(() {
      if (position != null) {
        _exibirMarcadorMotorista(position);
        _posicaoCamera = CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 19,
        );
        _movimentarCamera(_posicaoCamera);
        _localMotorista = position;
      }
    });
  }

  _movimentarCamera(CameraPosition cameraPosition) async {
    GoogleMapController googleMapController = await _controller.future;
    googleMapController
        .animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
  }

  _adicionarListenerLocalizacao() {
    var geolocator = Geolocator();
    var locationOptions = LocationOptions(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    geolocator.getPositionStream(locationOptions).listen((Position position) {
      _exibirMarcadorMotorista(position);
      _posicaoCamera = CameraPosition(
        target: LatLng(position.latitude, position.longitude),
        zoom: 19,
      );
      _movimentarCamera(_posicaoCamera);

      setState(() {
        _localMotorista = position;
      });
    });
  }

  _recuperarRequisicao() async {
    String idRequisicao = widget.idRequisicao;
    Firestore db = Firestore.instance;
    DocumentSnapshot documentSnapshot =
        await db.collection('requisicoes').document(idRequisicao).get();
    _dadosRequisicao = documentSnapshot.data;
    _adicionarListenerRequisicao();
  }

  _statusAguardando() {
    _alterarBotaoPrincipal(
      'Aceitar corrida',
      Color(0xff1ebbd8).withOpacity(0.9),
      () {
        _aceitarCorrida();
      },
    );
  }

  _statusAcaminho() {
    _alterarBotaoPrincipal(
        'A caminho do passageiro', Colors.grey.withOpacity(0.9), null);
  }

  _aceitarCorrida() async {
    Firestore db = Firestore.instance;
    String idRequisicao = _dadosRequisicao['id'];

    Usuario motorista = await UsuarioFirebase.getDadosUsuarioLogado();
    motorista.latitude = _localMotorista.latitude;
    motorista.longitude = _localMotorista.longitude;
    db.collection('requisicoes').document(idRequisicao).updateData({
      'motorista': motorista.toMap(),
      'status': StatusRequisicao.A_CAMINHO,
    }).then((_) {
//atualiza requisicao ativa
      String idPassageiro = _dadosRequisicao['passageiro']['idUsuario'];
      db.collection('requisicao_ativa').document(idPassageiro).updateData({
        'status': StatusRequisicao.A_CAMINHO,
      });

//salvar requisicao ativa para motorista
      String idMotorista = motorista.idUsuario;
      db
          .collection('requisicao_ativa_motorista')
          .document(idMotorista)
          .setData({
        'id_requisicao': idRequisicao,
        'id_usuario': idMotorista,
        'status': StatusRequisicao.A_CAMINHO,
      });
    });
  }

  _adicionarListenerRequisicao() async {
    Firestore db = Firestore.instance;
    String idRequisicao = _dadosRequisicao['id'];
    await db
        .collection('requisicoes')
        .document(idRequisicao)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.data != null) {
        Map<String, dynamic> dados = snapshot.data;
        String status = dados['status'];

        switch (status) {
          case StatusRequisicao.AGUARDANDO:
            _statusAguardando();
            break;
          case StatusRequisicao.A_CAMINHO:
            _statusAcaminho();
            break;
          case StatusRequisicao.VIAGEM:
            break;
          case StatusRequisicao.FINALIZADA:
            break;
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _recuperaUltimaLocalizacaoConhecida();
    _adicionarListenerLocalizacao();
    _recuperarRequisicao();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Painel corrida'),
      ),
      body: Container(
        child: Stack(
          children: <Widget>[
            GoogleMap(
              mapType: MapType.normal,
              initialCameraPosition: _posicaoCamera,
              onMapCreated: _onMapCreated,
              zoomControlsEnabled: false,
              //  myLocationEnabled: true,
              myLocationButtonEnabled: false,
              markers: _marcadores,
              //-23,559200, -46,658878
            ),
            Positioned(
              right: 0,
              left: 0,
              bottom: 0,
              child: Padding(
                padding: Platform.isIOS
                    ? EdgeInsets.fromLTRB(20, 10, 20, 25)
                    : EdgeInsets.all(10),
                child: RaisedButton(
                  child: Text(
                    _textoBotao,
                    style: TextStyle(color: Colors.white, fontSize: 20),
                  ),
                  color: _corBotao,
                  padding: EdgeInsets.fromLTRB(32, 16, 32, 16),
                  onPressed: _funcaoBotao,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
