import argparse
import re

def ersetze_und_speichere(dateiname_alt, dateiname_neu, ausgangsgruppe, zielgruppe):
    print(f'Nehme <{dateiname_alt}> und füge Lookup für <{ausgangsgruppe}> und <{zielgruppe}> ein, schreibe Ergebnis nach <{dateiname_neu}>')

    with open(dateiname_alt, 'r', encoding='utf-8') as f:
        fileContent = f.read()

    # Ersetzung 1
    fileContent = re.sub(
        r'\"operator\"\s*=>\s*\"is\",\s*\"value\"\s*=>\s*\[?"?[0-9]+\]?"?',
        f'"operator"=>"is", "value"=>lookup_group_id_or_default("{ausgangsgruppe}")',
        fileContent,
        re.M
    )

    # Ersetzung 2
    fileContent = re.sub(
        r'\"perform\"=>\s*{\"ticket\.group_id\"\s*=>\s*\{\"value\"=>\s*\[?"?[0-9]+\]?"?\}',
        f'"perform"=>{{"ticket.group_id"=>{{"value"=>lookup_group_id_or_default("{zielgruppe}")}}',
        fileContent,
        re.M
    )

    fileContent = "require_relative '../../customconfigutils/group_utils'\n" + fileContent

    with open(dateiname_neu, 'w', encoding='utf-8') as f:
        f.write(fileContent)

def main():
    parser = argparse.ArgumentParser(description="Ersetze Gruppeninformationen in einer Textdatei.")
    parser.add_argument('--input', required=True, help='Pfad zur Eingabedatei')
    parser.add_argument('--output', required=True, help='Pfad zur Ausgabedatei')
    parser.add_argument('--source-group', required=True, help='Name der Ausgangsgruppe')
    parser.add_argument('--target-group', required=True, help='Name der Zielgruppe')

    args = parser.parse_args()

    ersetze_und_speichere(args.input, args.output, args.source_group, args.target_group)

if __name__ == '__main__':
    main()
