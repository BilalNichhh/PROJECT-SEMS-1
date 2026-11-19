program GameCacingEdukasiSDL3;

{$mode objfpc}{$H+}

uses
  SysUtils, SDL3; // Pastikan unit wrapper SDL3 tersedia di path Free Pascal Anda

const
  GRID_W = 40;       // Lebar arena dalam satuan kotak (grid)
  GRID_H = 24;       // Tinggi arena dalam satuan kotak (grid)
  CELL_SIZE = 20;    // Ukuran 1 kotak dalam piksel (20x20 px)
  HUD_HEIGHT = 80;   // Tinggi area bawah untuk soal, nyawa, dan skor

  WINDOW_W = GRID_W * CELL_SIZE;
  WINDOW_H = (GRID_H * CELL_SIZE) + HUD_HEIGHT;

  // Kode arah custom pengganti kode ASCII crt
  ARAH_ATAS  = 1;
  ARAH_BAWAH = 2;
  ARAH_KIRI  = 3;
  ARAH_KANAN = 4;

var
  window: PSDL_Window;
  renderer: PSDL_Renderer;
  event: TSDL_Event;

  // Koordinat cacing (dalam satuan grid)
  cacingX, cacingY: array[1..100] of Integer;
  panjangCacing: Integer;
  arah, arahBerikutnya: Integer;

  // Variabel Soal Matematika
  angka1, angka2, jawabanBenar, jawabanSalah: Integer;

  // Koordinat Target Angka di Grid
  targetBenarX, targetBenarY: Integer;
  targetSalahX, targetSalahY: Integer;

  // Status Game
  gameJalan, gameOver: Boolean;
  skor, nyawa, i: Integer;
  lastTick, currentTick: UInt64;

procedure GenerateSoalDanTarget;
begin
  angka1 := Random(9) + 1;
  angka2 := Random(9) + 1;
  jawabanBenar := angka1 + angka2;

  repeat
    jawabanSalah := jawabanBenar + (Random(5) - 2);
  until (jawabanSalah <> jawabanBenar) and (jawabanSalah >= 0);

  // Tentukan posisi acak di dalam arena (hindari dinding luar)
  targetBenarX := Random(GRID_W - 4) + 2;
  targetBenarY := Random(GRID_H - 4) + 2;

  repeat
    targetSalahX := Random(GRID_W - 4) + 2;
    targetSalahY := Random(GRID_H - 4) + 2;
  until (Abs(targetBenarX - targetSalahX) > 2) or (Abs(targetBenarY - targetSalahY) > 2);
end;

procedure ResetGame;
begin
  panjangCacing := 3;
  cacingX[1] := 10; cacingY[1] := 12;
  cacingX[2] := 9;  cacingY[2] := 12;
  cacingX[3] := 8;  cacingY[3] := 12;

  arah := ARAH_KANAN;
  arahBerikutnya := ARAH_KANAN;
  skor := 0;
  nyawa := 3;
  gameOver := False;
  GenerateSoalDanTarget;
end;

procedure GambarKotak(gridX, gridY: Integer; r, g, b: UInt8);
var
  rect: TSDL_FRect;
begin
  rect.x := gridX * CELL_SIZE + 1;
  rect.y := gridY * CELL_SIZE + 1;
  rect.w := CELL_SIZE - 2;
  rect.h := CELL_SIZE - 2;
  SDL_SetRenderDrawColor(renderer, r, g, b, 255);
  SDL_RenderFillRect(renderer, @rect);
end;

procedure RenderTeksSkala(x, y, skala: Single; teks: string; r, g, b: UInt8);
begin
  SDL_SetRenderDrawColor(renderer, r, g, b, 255);
  SDL_SetRenderScale(renderer, skala, skala);
  SDL_RenderDebugText(renderer, x / skala, y / skala, PChar(teks));
  SDL_SetRenderScale(renderer, 1.0, 1.0); // Kembalikan skala ke normal
end;

procedure UpdateLogikaGame;
begin
  arah := arahBerikutnya;

  // Geser koordinat tubuh cacing dari belakang ke depan
  for i := panjangCacing downto 2 do
  begin
    cacingX[i] := cacingX[i - 1];
    cacingY[i] := cacingY[i - 1];
  end;

  // Gerakkan kepala cacing
  case arah of
    ARAH_ATAS:  Dec(cacingY[1]);
    ARAH_BAWAH: Inc(cacingY[1]);
    ARAH_KIRI:  Dec(cacingX[1]);
    ARAH_KANAN: Inc(cacingX[1]);
  end;

  // 1. Deteksi tabrakan dinding pagar
  if (cacingX[1] <= 0) or (cacingX[1] >= GRID_W - 1) or
     (cacingY[1] <= 0) or (cacingY[1] >= GRID_H - 1) then
  begin
    Dec(nyawa);
    if nyawa <= 0 then
    begin
      gameOver := True;
      Exit;
    end;
    // Reset kepala ke tengah
    cacingX[1] := GRID_W div 2;
    cacingY[1] := GRID_H div 2;
    arah := ARAH_KANAN;
    arahBerikutnya := ARAH_KANAN;
  end;

  // 2. Deteksi memakan JAWABAN BENAR
  if (cacingX[1] = targetBenarX) and (cacingY[1] = targetBenarY) then
  begin
    skor := skor + 10;
    if panjangCacing < 50 then Inc(panjangCacing);
    GenerateSoalDanTarget;
  end;

  // 3. Deteksi memakan JAWABAN SALAH
  if (cacingX[1] = targetSalahX) and (cacingY[1] = targetSalahY) then
  begin
    Dec(nyawa);
    if nyawa <= 0 then
      gameOver := True
    else
      GenerateSoalDanTarget;
  end;
end;

procedure RenderLayar;
var
  teksSoal, teksStatus: string;
begin
  // Bersihkan layar dengan warna latar gelap
  SDL_SetRenderDrawColor(renderer, 25, 28, 36, 255);
  SDL_RenderClear(renderer);

  if not gameOver then
  begin
    // 1. Gambar Dinding Pagar (Abu-abu kebiruan)
    for i := 0 to GRID_W - 1 do
    begin
      GambarKotak(i, 0, 100, 110, 130);
      GambarKotak(i, GRID_H - 1, 100, 110, 130);
    end;
    for i := 0 to GRID_H - 1 do
    begin
      GambarKotak(0, i, 100, 110, 130);
      GambarKotak(GRID_W - 1, i, 100, 110, 130);
    end;

    // 2. Gambar Target Angka di Arena (Kotak kuning + angka hitam)
    GambarKotak(targetBenarX, targetBenarY, 255, 215, 0);
    RenderTeksSkala(targetBenarX * CELL_SIZE + 3, targetBenarY * CELL_SIZE + 6, 1.2, IntToStr(jawabanBenar), 0, 0, 0);

    GambarKotak(targetSalahX, targetSalahY, 255, 215, 0);
    RenderTeksSkala(targetSalahX * CELL_SIZE + 3, targetSalahY * CELL_SIZE + 6, 1.2, IntToStr(jawabanSalah), 0, 0, 0);

    // 3. Gambar Cacing (Kepala hijau terang, badan hijau tua)
    GambarKotak(cacingX[1], cacingY[1], 80, 250, 120);
    for i := 2 to panjangCacing do
      GambarKotak(cacingX[i], cacingY[i], 40, 180, 80);

    // 4. Gambar HUD / Panel Soal di bagian bawah
    teksSoal := Format('SOAL: %d + %d = ?', [angka1, angka2]);
    teksStatus := Format('NYAWA: %d  |  SKOR: %d  |  [ESC] Keluar', [nyawa, skor]);

    RenderTeksSkala(20, (GRID_H * CELL_SIZE) + 15, 2.0, teksSoal, 255, 255, 255);
    RenderTeksSkala(20, (GRID_H * CELL_SIZE) + 48, 1.5, teksStatus, 180, 220, 255);
  end
  else
  begin
    // Layar Game Over
    RenderTeksSkala(WINDOW_W div 2 - 140, WINDOW_H div 2 - 80, 3.0, 'GAME OVER!', 255, 85, 85);
    RenderTeksSkala(WINDOW_W div 2 - 170, WINDOW_H div 2 - 20, 1.8, 'Hebat! Kamu sudah belajar berhitung.', 255, 255, 255);
    RenderTeksSkala(WINDOW_W div 2 - 130, WINDOW_H div 2 + 20, 2.0, Format('Skor Akhir: %d', [skor]), 80, 250, 120);
    RenderTeksSkala(WINDOW_W div 2 - 185, WINDOW_H div 2 + 70, 1.5, 'Tekan [SPACE] Main Lagi atau [ESC] Keluar', 200, 200, 200);
  end;

  SDL_RenderPresent(renderer);
end;

begin
  Randomize;

  // Inisialisasi SDL3
  if not SDL_Init(SDL_INIT_VIDEO) then
  begin
    WriteLn('Gagal inisialisasi SDL3: ', SDL_GetError);
    Halt(1);
  end;

  if not SDL_CreateWindowAndRenderer('Game Cacing Edukasi - SDL3', WINDOW_W, WINDOW_H, 0, @window, @renderer) then
  begin
    WriteLn('Gagal membuat Window/Renderer: ', SDL_GetError);
    SDL_Quit;
    Halt(1);
  end;

  ResetGame;
  gameJalan := True;
  lastTick := SDL_GetTicks;

  // Game Loop Utama
  while gameJalan do
  begin
    // 1. Tangani Input & Event Window
    while SDL_PollEvent(@event) do
    begin
      case event._type of
        SDL_EVENT_QUIT:
          gameJalan := False;

        SDL_EVENT_KEY_DOWN:
          begin
            if event.key.key = SDLK_ESCAPE then
              gameJalan := False
            else if gameOver and (event.key.key = SDLK_SPACE) then
              ResetGame
            else if not gameOver then
            begin
              case event.key.key of
                SDLK_UP:    if arah <> ARAH_BAWAH then arahBerikutnya := ARAH_ATAS;
                SDLK_DOWN:  if arah <> ARAH_ATAS  then arahBerikutnya := ARAH_BAWAH;
                SDLK_LEFT:  if arah <> ARAH_KANAN then arahBerikutnya := ARAH_KIRI;
                SDLK_RIGHT: if arah <> ARAH_KIRI  then arahBerikutnya := ARAH_KANAN;
              end;
            end;
          end;
      end;
    end;

    // 2. Update pergerakan cacing setiap 120 ms (non-blocking pengganti delay(120))
    currentTick := SDL_GetTicks;
    if (not gameOver) and (currentTick - lastTick >= 120) then
    begin
      UpdateLogikaGame;
      lastTick := currentTick;
    end;

    // 3. Render ulang seluruh tampilan
    RenderLayar;
    SDL_Delay(16); // Batasi ~60 FPS agar CPU tidak 100%
  end;

  // Bersihkan memori sebelum keluar
  SDL_DestroyRenderer(renderer);
  SDL_DestroyWindow(window);
  SDL_Quit;
end.
