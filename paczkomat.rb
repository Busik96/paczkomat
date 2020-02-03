# ## Przyklad uzycia
# paczkomat = Paczkomat::Urzadzenie.new('ST02')
# paczkomat.wolne_miejsce # => List: 30 | Mala: 20 | Srednia: 35 | Duza: 15
# # Z perspektywy kuriera:
# paczkomat.wloz_paczke(Paczka)
# # sprawdza czy dana paczka sie zmiesci
# # jesli brak miejsca - zwraca blad
# # jesli paczka byla nadana do innego paczkomatu niz ten - zwraca blad
# # jesli paczka pasuje - wysyla powiadomienie do usera na podany numer telefonu (z kodem odbioru)
# paczkomat.odbierz_paczki
# # zwraca wszystkie paczki ktore kurier moze zabrac (te ktore maja inny kod_urzadzenia)
# # w efekcie zwalnia skrytki
# # wymaga zamkniecia wszystkich drzwiczek

# # z perspektywy usera
# paczkomat.wyslij_paczke(numer_telefonu: '000000000', kod_targetu: 'ST01', wielkosc: :list)
# # sprawdza czy paczka sie zmiesci
# # jesli brak miejsca - zwraca blad
# # jesli paczka pasuje - sprawdzamy czy drzwi zamkniete
# # jesli paczka jest do tego samego targetu - powiadamiamy odbiorce

# paczkomat.odbierz_paczke(number_telefonu: '000000000', kod_odbioru: '12345')
# # sprawdza czy paczka dla tego numeru i kodu jest w paczkomacie
# # zwraca blad jesli takiej nie ma
# # otwiera skrytke jesli taka paczka jest i kod sie zgadza
# # prosi o zamkniecie drzwi

# # funkcje uniwersalne sterownika
# paczkomat.zamknij_skrytke(1)
# # zwraca blad jesli skrytka jest zamknieta, lub poprostu ja zamyka
# paczkomat.status
# # zwraca generalne informacje - czy sa paczki do odbioru przez kuriera etc.


# rubocop:disable all
require 'pry'

module Paczkomat
  WIELKOSCI_PACZEK = %w[mala srednia duza list]

  class Paczka
    attr_reader :numer_telefonu, :kod_targetu, :wielkosc

    def initialize(numer_telefonu:, kod_targetu:, wielkosc:)
      @numer_telefonu = numer_telefonu
      @kod_targetu = kod_targetu
      @wielkosc = wielkosc
    end

    def przypisz_kod(kod)
      @kod_odbioru = kod
    end

    def poprawny_kod?(kod)
      @kod_odbioru == kod
    end
  end

  class Skrytka
    attr_reader :numer, :wielkosc, :otwarta
    attr_accessor :zawartosc

    def initialize(numer, wielkosc)
      @numer = numer
      @wielkosc = wielkosc
      @zawartosc = nil
      @otwarta = false
    end

    def zamknij!
      return "Skrytka #{numer} już jest zamknięta" unless otwarta

      @otwarta = false
      puts "Skrytka #{numer} zamknięta!"
    end

    def otworz!(kod_odbioru: nil, forsuj: false)
      return "Skrytka #{numer} już jest otwarta!" if otwarta
      return otworz_sie if zawartosc.nil?
      return otworz_sie if forsuj
      return "Podaj kod odbioru" if kod_odbioru.nil?

      if zawartosc.poprawny_kod?(kod_odbioru)
        otworz_sie
      else
        "Niepoprawny kod!"
      end
    end

    private

    def otworz_sie
      @otwarta = true
      puts "Skrytka #{numer} otwarta!"
      paczka = zawartosc.dup
      @zawartosc = nil
      paczka
    end
  end


  class Urzadzenie
    class SkrytkaOtwartaError < StandardError; end
    attr_reader :kod_urzadzenia

    def initialize(kod_urzadzenia)
      @kod_urzadzenia = kod_urzadzenia
      @skrytki = []
      zamontuj_skrytki
    end

    def wolne_miejsce
      Paczkomat::WIELKOSCI_PACZEK.map do |typ|
        "#{typ.to_s.capitalize}: #{wolne_skrytki_typu(typ).size}"
      end.join(' | ')
    end

    def wloz_paczke(paczka, sprawdz_target: true)
      skrytki_otwarte?
      return "Musisz włożyć paczkę!" unless paczka.is_a?(Paczkomat::Paczka)
      return "Zły paczkomat!" if sprawdz_target && paczka.kod_targetu != kod_urzadzenia

      wolne_miejsce = wolne_skrytki_typu(paczka.wielkosc).first
      if !wolne_miejsce.nil?
        wolne_miejsce.otworz!
        wolne_miejsce.zawartosc = paczka
        puts "Zamknij skrytkę numer #{wolne_miejsce.numer}"
        wolne_miejsce.numer
      else
        "Brak miejsca na taką paczkę!"
      end
    end

    def odbierz_paczki
      skrytki_otwarte?
      do_odbioru = skrytki_do_wysylki.map { |el| el.otworz!(forsuj: true) }
      return "Nie ma zadnej paczki do odbioru!" if do_odbioru.empty?

      puts "Wyjmij paczki do wysyłki i zamknij wszystkie drzwiczki"
      do_odbioru
    end

    def wyslij_paczke(numer_telefonu:, kod_targetu:, wielkosc:)
      skrytki_otwarte?
      paczka = Paczka.new(
        numer_telefonu: numer_telefonu,
        kod_targetu: kod_targetu,
        wielkosc: wielkosc
      )
      wloz_paczke(paczka, sprawdz_target: false)
    end

    def odbierz_paczke(numer_telefonu:, kod_odbioru:)
      skrytki_otwarte?
      paczka_do_odbioru = @skrytki.find do |el|
        !el.zawartosc.nil? &&
        el.zawartosc.numer_telefonu == numer_telefonu &&
        el.zawartosc.poprawny_kod?(kod_odbioru)
      end

      if paczka_do_odbioru.nil?
        "Nie ma takiej paczki w tym paczkomacie"
      else
        paczka_do_odbioru.otworz!(kod_odbioru: kod_odbioru)
        puts "Wyjmij zawartosc i zamknij drzwiczki!"
        paczka_do_odbioru
      end
    end


    def zamknij_skrytke(numer)
      skrytka = @skrytki.find { |el| el.numer == numer }
      skrytka.zamknij!

      return if skrytka.zawartosc.nil? || skrytka.zawartosc.kod_targetu != kod_urzadzenia

      powiadom_odbiorce(skrytka.zawartosc)
    end

    def zamknij_wszystkie_skrytki
      @skrytki.select(&:otwarta).each(&:zamknij!)
    end

    def skrytki_otwarte?
      return unless @skrytki.any?(&:otwarta)

      raise SkrytkaOtwartaError
    end

    def status
      puts "Generalne informacje:"
      puts "Kod urzadzenia: #{@kod_urzadzenia}"
      puts "Ilosc skrytek: #{@skrytki.size}"
      puts "Ilosc wolnych skrytek: #{@skrytki.select { |el| el.zawartosc.nil? }.size}"
      puts "Ilosc paczek do odbioru: #{skrytki_do_wysylki.size}"
      puts "-----------------------------------"
    end

    private

    def skrytki_do_wysylki
      @skrytki.select { |el| !el.zawartosc.nil? && el.zawartosc.kod_targetu != kod_urzadzenia }
    end

    def czy_otwarta?(numer)
      @skrytki.find { |el| el.numer == numer }.otwarta
    end

    def wolne_skrytki_typu(typ)
      skrytki_typu(typ).select { |el| el.zawartosc.nil? }
    end

    def skrytki_typu(typ)
      @skrytki.select { |el| el.wielkosc == typ }
    end

    def zamontuj_skrytki
      (1..30).each do |numer|
        @skrytki << Skrytka.new(numer, 'list')
      end

      (31..50).each do |numer|
        @skrytki << Skrytka.new(numer, 'mala')
      end

      (51..85).each do |numer|
        @skrytki << Skrytka.new(numer, 'srednia')
      end

      (86..100).each do |numer|
        @skrytki << Skrytka.new(numer, 'duza')
      end

      def powiadom_odbiorce(paczka)
        kod_odbioru = 6.times.map { rand(10) }.join
        paczka.przypisz_kod(kod_odbioru)

        puts "Twoja paczka jest do odbioru w paczkomacie nr.#{paczka.kod_targetu}. Podczas odbioru proszę podać swój numer telefonu oraz kod odbioru: #{kod_odbioru}. Pozdrawiamy Paczkomaty XYZ"
      end
    end
  end

  class Apka
    GLOWNE_MENU = [
      {
        title: '1. Start',
        key: '1',
        submenu: [
          {
            title: '1. Odbierz paczkę',
            key: '1',
            action: :odbierz_paczke
          },
          {
            title: '2. Nadaj paczkę',
            key: '2',
            action: :nadaj_paczke
          },
          {
            title: 'Q. Wróc',
            key: 'q',
            action: :wroc_do_menu_glownego
          }
        ]
      },
      {
        title: '2. Kurier',
        key: 'okoń',
        submenu: [
          {
            title: '1. Odbierz paczki',
            key: '1',
            action: :odbierz_paczki
          },
          {
            title: '2. Włóz paczkę',
            key: '2',
            action: :wloz_paczke
          },
          {
            title: '3. Status',
            key: '3',
            action: :status
          },
          {
            title: 'Q. Wróc',
            key: 'q',
            action: :wroc_do_menu_glownego
          }
        ]
      },
      {
        title: '3. Zakoncz',
        key: '3',
        action: :zakoncz
      }
    ].freeze

    WLOZ_PACZKE_FORM = [
      { key: :kod_targetu, text: 'Podaj kod paczkomatu:'},
      { key: :numer_telefonu, text: 'Podaj numer telefonu:' },
      { key: :wielkosc, text: 'Wybierz wielkosc paczki:', values: %w[list mala srednia duza] }
    ].freeze

    ODBIERZ_PACZKE_FORM = [
      { key: :numer_telefonu, text: 'Podaj numer telefonu:' },
      { key: :kod_odbioru, text: 'Podaj kod odbioru:' }
    ].freeze

    attr_reader :paczkomat, :aktualne_menu, :menu_rodzica

    def initialize(kod_urzadzenia)
      @aktualne_menu = GLOWNE_MENU
      @paczkomat = Urzadzenie.new(kod_urzadzenia)
    end

    def run!
      pokaz_menu
    end

    private

    def pobierz_dane(form)
      dane = {}
      licznik = 0
      while true do
        element = form[licznik]
        puts element[:text]
        wartosc = gets.strip.chomp
        return pokaz_menu if wartosc == 'c'
        puts "Niepoprawna wartosc" && next if wartosc.empty?
        if !element[:values].nil? && !element[:values].include?(wartosc)
          puts "Niepoprawna wartosc - mozliwe opcje to: #{element[:values]}"
          next
        end

        dane[element[:key]] = wartosc
        if licznik < form.size - 1
          licznik = licznik + 1
        else
          break
        end
      end
      dane
    end

    def pokaz_menu
      return "Ktoras z skrytek jest otwarta! Zamknij drzwiczki!" if @paczkomat.skrytki_otwarte?
      if @aktualne_menu == GLOWNE_MENU
        puts "Witamy w paczkomacie #{@paczkomat.kod_urzadzenia}. Wybierz ponizsze opcje:"
      end
      @aktualne_menu.each { |el| puts el[:title] }
      czekaj_na_wybor
    rescue Paczkomat::Urzadzenie::SkrytkaOtwartaError
      czekaj_na_wybor
    end

    def wroc_do_menu_glownego
      @aktualne_menu = GLOWNE_MENU
      pokaz_menu
    end

    def nadaj_paczke
      dane_paczki = pobierz_dane(WLOZ_PACZKE_FORM)
      wynik = @paczkomat.wyslij_paczke(
        numer_telefonu: dane_paczki[:numer_telefonu],
        kod_targetu: dane_paczki[:kod_targetu],
        wielkosc: dane_paczki[:wielkosc]
      )
      zlap_blad(wynik, method(:nadaj_paczke))
    end

    def wloz_paczke
      dane_paczki = pobierz_dane(WLOZ_PACZKE_FORM)
      paczka = Paczka.new(dane_paczki)
      wynik = @paczkomat.wloz_paczke(paczka)
      zlap_blad(wynik, method(:wloz_paczke))
    end

    def odbierz_paczke
      dane_paczki = pobierz_dane(ODBIERZ_PACZKE_FORM)
      wynik = @paczkomat.odbierz_paczke(
        numer_telefonu: dane_paczki[:numer_telefonu],
        kod_odbioru: dane_paczki[:kod_odbioru]
      )
      zlap_blad(wynik, method(:odbierz_paczke))
    end

    def zlap_blad(wynik, akcja)
      if wynik.is_a?(String)
        puts wynik
        akcja.call
      else
        pokaz_menu
      end
    end

    def odbierz_paczki
      @paczkomat.odbierz_paczki
      puts "Zamknij za sobą wszystkie drzwiczki kurierze!"
      czekaj_na_wybor
    end

    def czekaj_na_wybor
      opcja = gets.strip.chomp
      return @paczkomat.zamknij_wszystkie_skrytki && pokaz_menu if opcja == 'z'
      wybrana_opcja = @aktualne_menu.find { |el| el[:key].downcase == opcja.downcase }
      if !wybrana_opcja.nil?
        if !wybrana_opcja[:submenu].nil?
          @aktualne_menu = wybrana_opcja[:submenu]
          pokaz_menu
        elsif !wybrana_opcja[:action].nil?
          self.send(wybrana_opcja[:action])
        end
      else
        puts "Nie ma takiej opcji"
        pokaz_menu
      end
    end

    def zakoncz
      exit
    end

    def status
      @paczkomat.status
      pokaz_menu
    end
  end
end

Paczkomat::Apka.new('ST01').run!





