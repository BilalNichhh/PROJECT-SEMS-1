program gim;
uses
   SDL3;
var
   window:PSDL_Window;
begin
   if not SDL_Init(SDL_INIT_VIDEO) then
   begin
      writeln('Waduh, SDL3 gagal jalan: ', SDL_GetError());
      Halt;
   end;
   window := SDL_CreateWindow('Game', 800, 600, 0);
   if window = nil then
   begin
      writeln('Gagal membuat jendela: ', SDL_GetError());
      SDL_Quit();
      Halt;
   end;
   writeln('Mantap! jendela kebuka');
   SDL_Delay(3000);
   SDL_DestroyWindow(window);
   SDL_Quit();
end.