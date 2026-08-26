"use client";

// Offline-Warteschlange. Der Server ist die Autorität; hier liegt nur, was noch
// nicht bei ihm angekommen ist.
//
// Drei Eigenschaften, ohne die das auf der Baustelle nicht trägt:
//   * die Kennung kommt vom Gerät, nicht vom Server — ein doppelt gesendeter
//     Eintrag erzeugt deshalb keinen zweiten Datensatz
//   * IndexedDB überlebt Appneustart und leeren Akku, anders als der Speicher
//     im Arbeitsspeicher
//   * angefügt wird, nie überschrieben: ein fehlgeschlagener Versuch verliert
//     nichts

const DB = "gewerk";
const LADEN = "warteschlange";

export type Eintrag = {
  id: string;
  art: "zeiteintrag" | "dokumentation" | "materialentnahme";
  nutzlast: Record<string, unknown>;
  erstellt: number;
  versuche: number;
};

function oeffnen(): Promise<IDBDatabase> {
  return new Promise((erfuellen, ablehnen) => {
    const anfrage = indexedDB.open(DB, 1);
    anfrage.onupgradeneeded = () => {
      const db = anfrage.result;
      if (!db.objectStoreNames.contains(LADEN)) {
        db.createObjectStore(LADEN, { keyPath: "id" });
      }
    };
    anfrage.onsuccess = () => erfuellen(anfrage.result);
    anfrage.onerror = () => ablehnen(anfrage.error);
  });
}

async function mitLaden<T>(
  modus: IDBTransactionMode,
  arbeit: (laden: IDBObjectStore) => IDBRequest<T>,
): Promise<T> {
  const db = await oeffnen();
  return new Promise<T>((erfuellen, ablehnen) => {
    const t = db.transaction(LADEN, modus);
    const anfrage = arbeit(t.objectStore(LADEN));
    anfrage.onsuccess = () => erfuellen(anfrage.result);
    anfrage.onerror = () => ablehnen(anfrage.error);
  });
}

export async function anstellen(
  art: Eintrag["art"],
  nutzlast: Record<string, unknown>,
): Promise<string> {
  const id = (nutzlast["id"] as string) ?? crypto.randomUUID();
  try {
    await mitLaden("readwrite", (l) =>
      l.put({ id, art, nutzlast: { ...nutzlast, id }, erstellt: Date.now(), versuche: 0 }),
    );
  } catch (fehler) {
    // In einem privaten Fenster oder bei gesperrtem Speicher gibt es keine
    // IndexedDB. Dann darf die Erfassung nicht still verschwinden — sie geht
    // direkt raus, und scheitert das auch, erfaehrt es die Aufruferin.
    const antwort = await fetch("/api/warteschlange", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ art, nutzlast: { ...nutzlast, id } }),
    });
    if (!antwort.ok) {
      throw new Error(
        "Der Eintrag konnte weder auf dem Gerät gespeichert noch gesendet werden. " +
          "Bitte notieren Sie ihn und melden Sie es dem Büro.",
      );
    }
  }
  return id;
}

export async function offen(): Promise<Eintrag[]> {
  const alle = await mitLaden<Eintrag[]>("readonly", (l) => l.getAll() as IDBRequest<Eintrag[]>);
  return alle.sort((a, b) => a.erstellt - b.erstellt);
}

async function abhaken(id: string) {
  await mitLaden("readwrite", (l) => l.delete(id));
}

async function versuchZaehlen(eintrag: Eintrag) {
  await mitLaden("readwrite", (l) => l.put({ ...eintrag, versuche: eintrag.versuche + 1 }));
}

// Sendet in der Reihenfolge, in der erfasst wurde. Bricht beim ersten Fehler
// ab: kommt der Server nicht, kommt er auch fuer den naechsten Eintrag nicht,
// und die Reihenfolge soll erhalten bleiben.
export async function absenden(): Promise<{ gesendet: number; verblieben: number }> {
  const liste = await offen();
  let gesendet = 0;

  for (const eintrag of liste) {
    try {
      const antwort = await fetch("/api/warteschlange", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ art: eintrag.art, nutzlast: eintrag.nutzlast }),
      });
      if (!antwort.ok) {
        await versuchZaehlen(eintrag);
        break;
      }
      await abhaken(eintrag.id);
      gesendet += 1;
    } catch {
      await versuchZaehlen(eintrag);
      break;
    }
  }

  return { gesendet, verblieben: (await offen()).length };
}
