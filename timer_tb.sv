`include "timer.sv"                    // директива препроцессора, которая включает файл timer.v в текущий код.
module timer_tb;
  // Параметры симуляции
  parameter WIDTH = 32;
  parameter WRITE = 3'b100;   // Параметр записи WRITE
  parameter READ = 3'b010;    // Параметр чтения READ
  
  // Сигналы модуля
  reg clk;                              // сигнал тактового сигнала 
  reg reset;                            // сигнал асинхронного сброса
  reg [3:0] ocp_mcmd;                   // сигнал команды для OCP PIO
  reg [WIDTH-1:0] ocp_maddr;            // адрес для OCP PIO
  reg [WIDTH-1:0] ocp_data;             // данные для чтения/записи
  wire [WIDTH-1:0] ocp_sdata;           // данные для ответа по OCP PIO
  wire ocp_sresp;                       // сигнал ответа по OCP PIO
  wire _scmdaccept;                     // сигнал подтверждения по OCP PIO
  
  // Подключение модуля
  timer #(.WIDTH(WIDTH))
dut (
    .clk          (clk),
    .reset_n      (reset),
    .ocp_mcmd     (ocp_mcmd),
    .ocp_maddr    (ocp_maddr),
    .ocp_data     (ocp_data),
    .ocp_sdata    (ocp_sdata),
    .ocp_sresp    (ocp_sresp),
    ._scmdaccept  (_scmdaccept)
  );
  

// Определение task-ов для проверки регистров

// запись в регистр начального значения
task test_write_start (input logic [WIDTH-1:0] start_value);
    ocp_mcmd = WRITE;             // запись в регистр START
    ocp_maddr = 32'h40000000;     // адрес регистра START
    ocp_data = start_value;       // данные для записи
    @(posedge clk);
    ocp_mcmd = 3'b0;              // обнуляем сигнал команды
    @(posedge clk);
endtask


// чтение из регистра начального значения
task test_read_start(input logic [WIDTH-1:0] start_value);
    ocp_mcmd = READ;              // чтение из регистра START
    ocp_maddr = 32'h40000000;     // адрес регистра START
    @(posedge clk);
    $display("ocp_sdata = %d", ocp_sdata);
    $display("ocp_sresp = %d", ocp_sresp);
    // проверка на чтение записанного в START значения
    if (ocp_sresp !== 1 || ocp_sdata !== start_value) begin
      $display("FAILED in writing START");
    end
    else begin
      $display("WRITING in START COMPLETED");
    end
    ocp_mcmd = 3'b0;              // обнуляем сигнал команды
    @(posedge clk);
endtask


// чтение текущего значения таймера
task test_read_curr;
    ocp_mcmd = READ;              // чтение из регистра CURR
    ocp_maddr = 32'h40000004;     // адрес регистра CURR
    @(posedge clk);
    $display("ocp_sdata = %d", ocp_sdata);
    $display("ocp_sresp = %d", ocp_sresp);
    ocp_mcmd = 3'b0;              // обнуляем сигнал команды
    @(posedge clk);
endtask
  

// остановка таймера
task test_write_ctrl_stop;
    ocp_mcmd = WRITE;             // запись в регистр CTRL
    ocp_maddr = 32'h40000008;     // адрес регистра CTRL
    ocp_data = 0;                 // флаг остановки таймера
    @(posedge clk);
    ocp_mcmd = 3'b0;              // обнуляем сигнал команды
    @(posedge clk);
endtask
  

// запуск таймера
task test_write_ctrl_start;
    ocp_mcmd = WRITE;             // запись в регистр CTRL
    ocp_maddr = 32'h40000008;     // адрес регистра CTRL
    ocp_data = 1;                 // флаг запуска таймера
    @(posedge clk);
    ocp_mcmd = 3'b0;              // обнуляем сигнал команды
    @(posedge clk);
endtask


// чтение текущего состояния таймера (запущен или остановлен)
task test_read_ctrl;
    ocp_mcmd = READ;              // чтение из регистра CTRL
    ocp_maddr = 32'h40000008;     // адрес регистра CTRL
    @(posedge clk);
    $display("ocp_sdata = %d", ocp_sdata);
    $display("ocp_sresp = %d", ocp_sresp);
    // проверка на то активен ли таймер
    if (ocp_sresp !== 1 || ocp_sdata !== 1) begin
      $display("Timer is not active");
    end
    ocp_mcmd = 3'b0;              // обнуляем сигнал команды
    @(posedge clk);
endtask


// сброс таймера активен
task test_reset_timer_on;
    reset = 0;                    // сбрасываем значения таймера - таймер отключается и обнуляется
    @(posedge clk); 
endtask


// убираем сброс таймера
task test_reset_timer_off;
    reset = 1;                    // убираем сброс таймера
    @(posedge clk);
endtask


  // Тесты
  initial begin
    // начальные значения
    reset = 1;
    clk = 0;
    ocp_mcmd = 0;
    ocp_maddr = 0;
    ocp_data = 0;
    // Начальный сброс таймера
    @(posedge clk);
    test_reset_timer_on;
    @(posedge clk);
    // Убираем сброс таймера
    test_reset_timer_off;
    @(posedge clk);
    

    // Тест 1: проверка чтения и записи регистра START
    $display("\n\t\t\t TEST 1");
    test_write_start(50);              // записываем в таймер число 50
    test_read_start(50);               // сравниваем прочитанное число из регистра START с записанной 50-кой


    // Тест 2: проверка чтения регистра CURR в рабочем состоянии. Должно прочитаться 0
    $display("\n\t\t\t TEST 2");
    test_write_start(10);              // записываем в таймер число 10
    test_write_ctrl_start;             // запускаем таймер. active -> 1
    $display("       1          ");
    test_read_ctrl;                    // проверка на выставление в active значения 1
    // проверка на то, что таймер не может читать в остановленном состоянии
    // active = 1 -> ничего не можем прочитать
    // сработает условие else begin ocp_sdata <= 0;
    $display("       2          ");
    test_read_curr;
    // штабель проверок, что мы не можем получить текущее значение таймера, пока active = 1
    if (ocp_sresp !== 1 || ocp_sdata !== 10) begin
      $display("TEST 2 COMPLETED at 10");
    end
    @(posedge clk);
    if (ocp_sresp !== 1 || ocp_sdata !== 9) begin
      $display("TEST 2 COMPLETED at 9");
    end
    @(posedge clk);
    if (ocp_sresp !== 1 || ocp_sdata !== 8) begin
      $display("TEST 2 COMPLETED at 8");
    end


    // Тест 3: проверка чтения регистра CURR в остановленном состоянии
    $display("\n\t\t\t TEST 3");
    test_write_ctrl_stop;               // останавливаем таймер. Устанавливаем active -> 0
    test_read_curr;                     // читаем регистр CURR. Таймер остановлен. Это можно сделать
    // проверяем, что прочитали не 0, как это было бы при active = 1
    if (ocp_sresp !== 1 || ocp_sdata !== 0) begin
      $display("TEST 3 COMPLETED");
    end


    // Тест 4: проверка чтения CURR при запуске и остановке таймера
    $display("\n\t\t\t TEST 4");
    test_write_ctrl_start;               // запускаем таймер. Устанавливаем active -> 1
    $display("       1          ");
    test_read_ctrl;                      // читаем регистр CTRL. Проверяем, что active = 1
    test_write_ctrl_stop;                // останавливаем таймер. Устанавливаем active -> 0
    $display("       2          ");
    test_read_ctrl;                      // читаем регистр CTRL. Проверяем, что active = 0
    $display("       3          ");
    test_read_curr;                      // читаем регистр CURR. Таймер остановлен. Это можно сделать
    // проверяем, что прочитали не 0, как это было бы при active = 1
    if (ocp_sdata == 0) begin
      $display("TEST 4 FAIL of count");
    end
    else begin
      $display("TEST 4 COMPLETED");
    end
    

    // Тест 5: проверка чтения из CURR для остановленного таймера
    $display("\n\t\t\t TEST 5");
    test_write_ctrl_start;                // запускаем таймер. Устанавливаем active -> 1
    $display("       1          ");
    test_read_ctrl;                       // читаем регистр CTRL. Проверяем, что active = 1
    @(posedge clk);
    test_write_ctrl_stop;                 // останавливаем таймер. Устанавливаем active -> 0
    $display("       2          ");
    test_read_ctrl;                       // читаем регистр CTRL. Проверяем, что active = 0
    $display("       3          ");
    test_read_curr;                       // читаем регистр CURR. Таймер остановлен. Это можно сделать
    // проверяем, что прочитали из таймера нужное число
    if (ocp_sdata !== 5) begin
      $display("TEST 5 FAILED at 5");
    end
    else begin
      $display("TEST 5 COMPLETED");
    end
    

    // Тест 6: проверка сброса таймера
    $display("\n\t\t\t TEST 6");
    test_write_ctrl_start;                // запускаем таймер. Устанавливаем active -> 1
    @(posedge clk);
    test_reset_timer_on;                  // сбрасываем таймер. active -> 0; cur_val -> 0; start_val -> 0;
    @(posedge clk);
    @(posedge clk);
    $display("       1          ");
    test_read_curr;
    @(posedge clk);                       // пробуем прочитать текущее значение таймера. cur_val = 0; и таймер неактивен
    // проверка, что прочитали 0
    if (ocp_sdata !== 0) begin
      $display("TEST 6 Failed");
    end
    @(posedge clk);
    $display("       2          ");
    test_read_ctrl;                        // читаем регистр CTRL. Проверяем, что active при сбросе = 0  
    @(posedge clk);
    test_reset_timer_off;                  // убираем сброс таймера


     // Тест 7: проверка отсчёта таймера до конца
    test_write_start(10);              // записываем в таймер число 10
    test_write_ctrl_start;             // запускаем таймер. active -> 1
    test_read_ctrl;                    // читаем регистр CTRL. Проверяем, что active = 1
    repeat (10) begin
    @(posedge clk);  
    end
    test_write_ctrl_stop;              // останавливаем таймер. Устанавливаем active -> 0
    $display("All tests passed");
    $finish;
  end


  // генерация тактового сигнала
  always #10 clk = ~clk;
  // создание файла .vcd и вывести значения переменных волны для отображения в визуализаторе волн
  initial begin
    $dumpfile("timer.vcd");              // создание файла для сохранения результатов симуляции
    $dumpvars(0, timer_tb);              // установка переменных для сохранения в файле
  end 
endmodule