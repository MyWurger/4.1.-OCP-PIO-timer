module timer #(
  parameter WIDTH = 32         // ширина таймера в битах, по умолчанию 32
) (
  input wire clk,              // сигнал тактового сигнала
  input wire reset_n,          // сигнал асинхронного сброса по негативному фронту
  input wire[3:0] ocp_mcmd,    // сигнал команды для OCP PIO
  input wire [31:0] ocp_maddr, // адрес для OCP PIO
  input wire [31:0] ocp_data,  // данные для чтения/записи
  output reg [31:0] ocp_sdata, // данные для ответа по OCP PIO
  output reg ocp_sresp,        // сигнал ответа по OCP PIO
  output reg _scmdaccept       // сигнал подтверждения по OCP PIO
);

  // Параметры адресного пространства 
  parameter TIMER_START_ADDR = 32'h40000000; // адрес стартового значения таймера
  parameter TIMER_CURR_ADDR  = 32'h40000004; // адрес текущего значения таймера
  parameter TIMER_CTRL_ADDR  = 32'h40000008; // адрес регистра старт-стоп таймера

  // Локальные переменные
  reg [WIDTH-1:0] start_val;   // начальное значение таймера
  reg [WIDTH-1:0] cur_val;     // текущее значение таймера
  reg active;                  // флаг активности таймера
  reg busy;                    // флаг занятости таймера

  // Параметры записи и чтения
  parameter WRITE = 3'b100;   // параметр записи WRITE
  parameter READ = 3'b010;    // параметр чтения READ

  always @(posedge clk) begin
    // присутствует отрицательный фронт сигнала сброса
    if (!reset_n) begin
      start_val <= 0;          // сбрасываем начальное значение таймера
      cur_val <= 0;            // сбрасываем текущее значение таймера
      active <= 0;             // сбрасываем флаг активности таймера
      ocp_sdata <= 0;          // сбрасываем данные ответа таймера
      busy <= 0;               // сбрасывыаем флаг занятости таймера
    end
    // Декремент таймера при активном состоянии
    if (active && cur_val != 0) begin
      cur_val <= cur_val - 1;
    end
    // Установка стартового значения таймера, если текущее значение равно 0 и таймер активен
    if (active && cur_val == 0) begin
      cur_val <= start_val;
    end
  end

  always @(posedge ocp_maddr, ocp_mcmd) begin
    // Чтение/запись регистров через интерфейс OCP PIO
    ocp_sresp <= 0;              // операции ещё нету -> сигнал ответа 0
    _scmdaccept <= 0;            // операции ещё нету -> сигнал подтверждения 0

    // если операция уже выполняется
    if (busy) begin
      // Отклоняем операции, если интерфейс занят
      ocp_sresp <= 1'b0;
      _scmdaccept <= 1'b0;
    end
    
    else begin
    busy <= 1'b1;                         // интерфейс занят
    // проверяем команду на обращение к регистрам
    case (ocp_maddr)
      // обращение к регистру start_val
      TIMER_START_ADDR: begin
        if (ocp_mcmd == READ) begin       // чтение данных в регистре
          ocp_sdata <= start_val;
        end
        else if (ocp_mcmd == WRITE) begin // запись данных в регистр start_val 
          start_val <= ocp_data;
        end
        // операция выполнена. Устанавливаем сигналы подтверждения операции
        ocp_sresp <= 1;
        _scmdaccept <= 1;
      end

      // обращение к регистру cur_val
      TIMER_CURR_ADDR: begin
        if (ocp_mcmd == READ) begin        // чтение данных из регистра текущего знаения cur_val
          if (active == 0) begin           // чтение разрешено только в остановленном состоянии
            ocp_sdata <= cur_val;          // читаем данные
          end
          // иначе, если таймер не остановлен - записываем 0
          else begin
            ocp_sdata <= 0;
          end
        end
        // операция выполнена. Устанавливаем сигналы подтверждения операции
        ocp_sresp <= 1;
        _scmdaccept <= 1;
      end

      // обращение к регистру active
      TIMER_CTRL_ADDR: begin
      // читаем значение регистра
      if (ocp_mcmd == READ) begin          // чтение данных из регистра активности active
        ocp_sdata <= active;               // чтение данных об активности таймера
        // операция выполнена. Устанавливаем сигналы подтверждения операции
        ocp_sresp <= 1;
        _scmdaccept <= 1;
      end
      //записать значения в регистр
      else if (ocp_mcmd == WRITE) begin          // запись значения флага активности таймера 
        if (ocp_data == 1 && active == 0) begin  // Таймер был выключен и пришло значение 1. Включение таймера
          active <= 1;                           // устанавливаем флаг активности таймера
          cur_val <= start_val;                  // устанавливаем значение отсчёта таймера для начала работы
          // операция выполнена. Устанавливаем сигналы подтверждения операции
          ocp_sresp <= 1;
          _scmdaccept <= 1;
        end
        // таймер активен и пришел флаг сброса активности
        else if (ocp_data == 0 && active == 1) begin        // выключение таймера
          active <= 0;                                       // убираем флаг активности таймера
          // операция выполнена. Устанавливаем сигналы подтверждения операции
          ocp_sresp <= 1;
          _scmdaccept <= 1;
        end 
        // таймер активен и пришел флаг установки активности
        else if (ocp_data == 1 && active == 1) begin        // состояние таймера не изменится
          active <= 1;                                      // устанавливаем флаг активности таймера
          // операция выполнена. Устанавливаем сигналы подтверждения операции
          ocp_sresp <= 1;
          _scmdaccept <= 1;
        end
        // таймер неактивен и пришел флаг сброса активности
        else if (ocp_data == 0 && active == 0) begin        // состояние таймера не изменится
          active <= 0;                                      // сбрасываем флаг активности таймера
          // операция выполнена. Устанавливаем сигналы подтверждения операции
          ocp_sresp <= 1;
          _scmdaccept <= 1;
        end
        // непредусмотренное состояние - операция не выполнена
        else  begin
          ocp_sresp <= 0;
          _scmdaccept <= 0;
        end
      end
    end
    // попали не в тот регитср - операция не выполнена. Флаги подтверждения 0
    default: begin
        ocp_sresp <= 0;
        _scmdaccept <= 0;
    end
    endcase
    end;
  end

  // Логика сброса флага занятости интерфейса
  // если таймер не занят, т.е флаг подтверждения новой операции 0
  always @(negedge ocp_sresp) begin
      // сбрасываем флаг занятости
      busy <= 1'b0;
  end
endmodule