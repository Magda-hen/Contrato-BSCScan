// SPDX-License-Identifier: GPL-3.0
/*
    Contrato principal de registro de sociedad con sus miembros y capitales para iniciar operaciones
    
    FUNCIONES Públicas Lectura:
    
    void
    balanceSociedad: Muestra el balance actual de la cuenta del contrato
    return uint256
    
    void
    getAllSocios: retorna un arreglo con las direcciones de las llaves Públicas de todos los socios
    return address []
    
    void
    getMisDatosSocio: retorna una estructura con los datos del socio que realiza la consulta, solo si es socio
    return struct
    
    address
    getDatosBySocioSocio: retorna una estructura con los datos del socio asociado a la llave pública, solo si el sender es socio
    return struct
    
    address
    getPorcentajeParticipacion: retorna un uint256 con los el porcentaje actual de participacion en base a 1000% asociado a la llave pública, solo si el sender es socio
    return uint256
    
    
    void
    calcularCantidadRecibirRetiroUnilateral: retorna un uint256 con la cantidad de ganancia que recibiria el socio asociado a la llave pública en caso se que retire todo su capital y ganancias, solo si el sender es socio
    return uint256
    
    
    
    FUNCIONES Públicas Lectura:
    
    
    
    
    
*/
pragma solidity >=0.7.0 <0.8.8;

contract SociedadAdministradoraCriptoActivos{
    
    string public sociedad;
    address manager; // dirección del que administra el contrato
    address [] public socios_array;  //arreglo con las direcciones de los socios
    uint256 [] public Inversiones_array;  //arreglo con las direcciones de los socios
    uint256 public priceStock; // valor de una acción de participación, esto es el balance total entre 100%
    uint256 porcenPartidaInversiones; // esto es el % de dinero permitido para retirar del capital por parte de la administradora para hacer inversiones
    uint256 public inversionSocios; // esto es el total de capital puesto por todos los inversores
    uint256 decimalsParticipacion;
    uint256 public porcentaje_penalizacion_fin_unilateral; //este es el porcentaje que se grava por retirarse de la sociedad unilateralmente
    uint256 public saldo_finiquitos; //este es el saldo que la cuenta guarda de lo penalizado por retirarse unilateralmente. luego es repartiido entre socios
    uint256 public debitado; // esto es el dinero sacado del balance de la cuenta para hacer inversiones
    uint256 public diasBloqueoRetiros; // este es el numero de bloques que debe esperar un socio para hacer un nuevo retiro de ganancias
    uint256 public diasFinContrato;
    bool public permitir_ingreso_capital;
    
    mapping ( address => Socio) socio; //datos de los socios asociados a su billetera
    mapping ( uint256 => Inversiones) public inversiones; //retiro de caital que ha hecho la sociedad para ser invertido externamente
    mapping ( address =>  mapping (uint256 => uint256)) public socioPartida;//relacion socio con partidas de inversiones individuales
    
    struct Inversiones{
        uint256 cantidadInvertida;
        uint256 bloqueCreacion;
        uint256 cantidadRetornada;
        string descrip;
        bool cerrada;
        address [] socios_participantes_partida;
        uint256 [] porcentajes_participacion;
    }
    
    struct Socio{
        string name;
        string id;
        address direccion_cartera; // esta es la direccion que usa el socio para recibir sus beneficios
        uint porcentaje_participacion;
        uint256 capital_invertido;
        uint256 bloqueCreacion;    
        uint256 acu_ganancias;
        uint256 ultimo_retiro;
        uint256 limite_permitido_inversion;
        uint256 last_update_inversion;//ultima vez que se actalizaron los datos
    }
    
    modifier SoloSocios(){ //solo los socios pueden ejecutar las funciones con este modificador
        require(socio[msg.sender].direccion_cartera == msg.sender);
        _;
    }
    
    modifier SoloManager(){ //solo el  Director Principal pueden ejecutar las funciones con este modificador
        require(manager == msg.sender);
        _;
    }
    
    modifier NoEnviarEther(){//para asergurar que al ejecutar una funcion no se pague ETHER, solo el fee del gas en cualquier caso
        require(msg.value == 0);
        _;
    }
    
    constructor (string memory _nombre_sociedad) NoEnviarEther payable{
         // al crear la sociedad el capital debe ser 0, luego los socios invertiran individualmente
        manager = msg.sender;// se establece como manager por defecto a quien despliega, luego puede seder la administracion
        sociedad = _nombre_sociedad;
        priceStock = 0;
        decimalsParticipacion = 1000;
        permitir_ingreso_capital = true;
        Inversiones_array.push(block.timestamp);//identificador de la primera partida de inversión
        diasBloqueoRetiros = 0;
    }
    
    event Valor(uint256 _valor);
    event Direccion(address _direccion);
    
    function balanceSociedad() public view returns (uint256){
        return address(this).balance;
    }
    
    function addSocio(string memory _name, string memory _id, address _nuevo_socio, uint256 limite_permitido_inversion) public payable NoEnviarEther SoloManager {
        require(socio[msg.sender].direccion_cartera != _nuevo_socio);// para no reperir al agregar socios nuevos
        socio[_nuevo_socio].name = _name;
        socio[_nuevo_socio].id = _id;
        socio[_nuevo_socio].direccion_cartera = _nuevo_socio;
        socio[_nuevo_socio].capital_invertido = 0;
        socio[_nuevo_socio].porcentaje_participacion = 0;
        socio[_nuevo_socio].bloqueCreacion = block.number;
        socio[_nuevo_socio].limite_permitido_inversion = limite_permitido_inversion;
        
        //agregamos la direccion a un arreglo de socios para iterar
        socios_array.push(_nuevo_socio);
    }
    
    function setLimiteInversion(address _socio, uint256 _limite)public SoloManager returns(bool _status){
        socio[_socio].limite_permitido_inversion = _limite;
        return true;
    }
    
    function setPorcentajePenalizacionSalidaUnilateral(uint256 _porcentaje)public SoloManager returns(bool _status){
        require(_porcentaje <= 100);//no se puede pasar del 100%
        porcentaje_penalizacion_fin_unilateral = _porcentaje;
        return true;
    }
    
    function getAllSocios() external view returns( address[]  memory){
        return socios_array;
    }
    
    function getMisDatosSocio() public view returns(string memory, address, uint256 _capital_invertido, uint256 _acu_ganancias, uint256 _ultimo_retiro, uint256 blk_creacion){
        return(socio[msg.sender].name, socio[msg.sender].direccion_cartera, socio[msg.sender].capital_invertido, socio[msg.sender].acu_ganancias, socio[msg.sender].ultimo_retiro,  socio[msg.sender].bloqueCreacion);
    }
    
    function getDatosBySocio(address _socio) public view returns(string memory, address, uint256 _capital_invertido, uint256 _acu_ganancias, uint256 _ultimo_retiro, uint256 blk_creacion){
        return(socio[_socio].name, socio[_socio].direccion_cartera, socio[_socio].capital_invertido, socio[_socio].acu_ganancias, socio[_socio].ultimo_retiro,  socio[_socio].bloqueCreacion);
    }
    
    function getPorcentajeParticipacion(address _socio) external view SoloSocios returns(uint){
        uint256 porcentaje =  decimalsParticipacion * socio[_socio].capital_invertido  / inversionSocios;
        return porcentaje;
    }

    //cuando un socio envía más capital aumenta su cuota de participación en la empresa
    function sendCapitalPorSocio() public payable SoloSocios returns (uint){
        require(permitir_ingreso_capital == true);
        //validar que no pueda enviar más capital del permitido
        require((socio[msg.sender].capital_invertido + msg.value)  <= socio[msg.sender].limite_permitido_inversion);
        socio[msg.sender].capital_invertido += msg.value;
        inversionSocios += msg.value;
        calcularPorcentajeParticipacion(msg.sender);
        socio[msg.sender].last_update_inversion = block.timestamp;
        
        //se guarda su porcentaje_participacion para este periodo de partidas
        socioPartida[msg.sender][Inversiones_array[Inversiones_array.length - 1]] = calcularPorcentajeParticipacion(msg.sender); 
        return  socio[msg.sender].porcentaje_participacion;
        
    }
    
    function calcularPorcentajeParticipacion(address _direccion) internal  returns(uint256){
        socio[_direccion].porcentaje_participacion =  decimalsParticipacion * socio[_direccion].capital_invertido  / inversionSocios;
        return socio[_direccion].porcentaje_participacion;
    }
    
    function reescrituraPorcentajesParticipacion() internal returns(bool){
        for(uint32 i = 0; i < socios_array.length; i++){
            socio[socios_array[i]].porcentaje_participacion =  decimalsParticipacion * socio[socios_array[i]].capital_invertido  / inversionSocios;
            //se guarda el porcentaje actual del socio en la partiida que se está sacando para cuando retorne beneficios saber cuanto le correspodia en ese momento
            socioPartida[socios_array[i]][Inversiones_array[Inversiones_array.length - 1]] = socio[socios_array[i]].porcentaje_participacion;
        }
        return true;
    }
    
    //envio de ganancias de las actividades de la sociedad al acu_ganancias del contrato
    function sendProfits(uint256 _timestamp_partida)public payable returns (bool _status){
    
        uint256 cantidad_repartida;
    
        //repartir ganancias entre los socios según su Porcentaje de participación es esta partida
        for (uint i=0; i< inversiones[_timestamp_partida].socios_participantes_partida.length; i++) {
            //el calculo de % se hace en base a 1000% y no a 100% para resolver el problema de precisión por no tener float en solidity    
            //uint256 porc_part = decimalsParticipacion * socio[socios_array[i]].capital_invertido  / inversiones[_timestamp_partida].cantidadInvertida;
            socio[socios_array[i]].acu_ganancias += (msg.value * socioPartida[socios_array[i]][_timestamp_partida] ) / decimalsParticipacion;
        
            cantidad_repartida += socio[socios_array[i]].acu_ganancias;
        }
        
        return true;
    }
    
    //para enviar fondos sin afectar los saldos 
    function sendFound()public payable{
        debitado -= msg.value;
    }
    
    function getCalculoProfit()public payable returns(uint256 _ganancias){
        uint256 gananciasSociedad = address(this).balance - inversionSocios;
        uint256 gananciasSocio = gananciasSociedad * calcularPorcentajeParticipacion(msg.sender)/ 1000;
        return gananciasSocio;
    }
    
    function getCalcularPriceStock()public view returns(uint256 _valor_stock){
        address(this).balance  / 1000;
        return priceStock;
    }
    
    function calcularBetweenDates(uint256 _fecha_inicio, uint256 _fecha_fin)internal pure returns (uint256 _dias){
        uint diff = (_fecha_fin - _fecha_inicio) / 60 / 60 / 24; 
        return diff;
    }
    
    //retiro de ganancias 
    function retirarGanancias(uint256 monto)public payable NoEnviarEther SoloSocios returns(bool _status){
        require(socio[msg.sender].acu_ganancias >= monto);// debe tener en ganacias al menos la cantidad que pide
        emit Valor(diasBloqueoRetiros);
        emit Valor(calcularBetweenDates(socio[msg.sender].bloqueCreacion, block.timestamp));
        
        
        require (diasBloqueoRetiros <= calcularBetweenDates(socio[msg.sender].bloqueCreacion, block.timestamp));
        socio[msg.sender].acu_ganancias  -= monto;
        payable(msg.sender).transfer(monto);
        return true;
    }
    
    function finContratoUnilateral() public payable SoloSocios returns(uint256 _total_acumulado, uint256 _porcentaje_penalizado, uint256 _total_penalizdo, uint256 _total_retirado){
        //finiquita el contrato enviando al socio su porcentaje del capital invertido + el acu_ganancias del momento menos el monto correspondiente a la penalización
        require (diasBloqueoRetiros > calcularBetweenDates(socio[msg.sender].bloqueCreacion, block.timestamp));
        
        //calcular porcentaje de porcentaje_penalizacion_fin_unilateral
        uint256 acumulado = (socio[msg.sender].capital_invertido + socio[msg.sender].acu_ganancias);
        uint256 penal = (acumulado * porcentaje_penalizacion_fin_unilateral ) / 100;
        uint256 retirar = (acumulado - penal);
        
        //se actualizan las variables contables
        inversionSocios -= socio[msg.sender].capital_invertido;// se resta el capital del socio del capital total, por lo que su participacion llega a 0
        socio[msg.sender].capital_invertido = 0;
        socio[msg.sender].acu_ganancias = 0;
        socio[msg.sender].porcentaje_participacion = 0;
        
        //el saldo penalizado se contabiliza aparte
        saldo_finiquitos += penal;
    
        payable(msg.sender).transfer(retirar);
        
        return (acumulado, porcentaje_penalizacion_fin_unilateral, penal,  retirar);
    }
    
    function setCantidadDiasBloqueos(uint256 _dias_bloqueos)public SoloManager returns(bool _status){
        diasBloqueoRetiros = _dias_bloqueos;
        return true;
    }
    
    function withDrawPartidaParaInvertir(uint256 _monto) public payable SoloManager NoEnviarEther returns(bool _status){
        require(address(this).balance >= _monto);
        debitado += _monto;
        
        uint256 timestamp = block.timestamp;//esto será el nuevo periodo de partidas que reemplaza al actual
        uint256 ultimo_periodo_inversiones = Inversiones_array[Inversiones_array.length - 1];//tomar perido actual de inversiones
        
        //se guarda registro de lo retirado y el porcentaje que le corresponde a cada socio sobre la inversión
        inversiones[ultimo_periodo_inversiones].cantidadInvertida = _monto;
        inversiones[ultimo_periodo_inversiones].cantidadRetornada = 0;
        inversiones[ultimo_periodo_inversiones].cerrada = false;
        inversiones[ultimo_periodo_inversiones].bloqueCreacion = block.number;
        
        inversiones[ultimo_periodo_inversiones].socios_participantes_partida = socios_array;
        
        //calculo de porcentaje de participacion por socio para esta partida en particular
        reescrituraPorcentajesParticipacion();
        
        //se crea un nuevo periodo de inversiones para los proximos socios
        Inversiones_array.push(timestamp); 
        
        //todo: calcular el gas utilizado en esta operación y cobrarlo a los socios involucrados al momento de retornar ganancias
        
        payable(msg.sender).transfer(_monto);
        return true;
    }
    
    
    function setHabilitarIngresosCapital(bool _habilitar) public payable SoloManager {
        permitir_ingreso_capital = _habilitar;
    }
    
    function calcularCantidadRecibirRetiroUnilateral(address _address)public view returns(uint256 _montoEstimado){
        //calcular porcentaje de porcentaje_penalizacion_fin_unilateral
        uint256 acumulado = (socio[_address].capital_invertido + socio[_address].acu_ganancias);
        uint256 penal = (acumulado * porcentaje_penalizacion_fin_unilateral ) / 100;
        uint256 retirar = (acumulado - penal);
        
        return retirar;
    }
    
    /*  
        todo funcion para asignar balance a socio desde la cuenta del manager
        todo funcion para ver limite de capital restante permitido por socio
        todo asignar descripcion al las partidas de inversion y actualizar variables al reponer montos invertidos
        
    */
    
}