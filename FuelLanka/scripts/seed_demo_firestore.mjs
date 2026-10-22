import fs from "node:fs";

const projectID = process.env.FIREBASE_PROJECT_ID ?? "fuelsmart-lk";
const configPath = process.env.FIREBASE_CONFIG_PATH ?? "/tmp/fuellanka-firebase-config/configstore/firebase-tools.json";
const token = process.env.FIREBASE_ACCESS_TOKEN ?? JSON.parse(fs.readFileSync(configPath, "utf8")).tokens?.access_token;

if (!token) throw new Error("Firebase access token was not found. Run firebase login first.");

const stations = [
    ["colombo-fort", "Ceypetco Colombo Fort", "Sir Chittampalam A. Gardiner Mawatha, Colombo 02", "Ceypetco", 6.9271, 79.8612],
    ["narahenpita", "Ceypetco Narahenpita", "Elvitigala Mawatha, Colombo 05", "Ceypetco", 6.8952, 79.8779],
    ["nugegoda", "Lanka IOC Nugegoda", "High Level Road, Nugegoda", "Lanka IOC", 6.8649, 79.8997],
    ["moratuwa", "Ceypetco Moratuwa", "Galle Road, Moratuwa", "Ceypetco", 6.7730, 79.8816],
    ["negombo", "Lanka IOC Negombo", "Colombo Road, Negombo", "Lanka IOC", 7.2008, 79.8737],
    ["gampaha", "Ceypetco Gampaha", "Colombo Road, Gampaha", "Ceypetco", 7.0873, 80.0144],
    ["kandy", "Ceypetco Kandy", "Peradeniya Road, Kandy", "Ceypetco", 7.2843, 80.6298],
    ["peradeniya", "Lanka IOC Peradeniya", "Colombo Road, Peradeniya", "Lanka IOC", 7.2667, 80.5960],
    ["kurunegala", "Ceypetco Kurunegala", "Colombo Road, Kurunegala", "Ceypetco", 7.4863, 80.3623],
    ["anuradhapura", "Ceypetco Anuradhapura", "Maithripala Senanayake Mawatha, Anuradhapura", "Ceypetco", 8.3114, 80.4037],
    ["jaffna", "Lanka IOC Jaffna", "Kandy Road, Jaffna", "Lanka IOC", 9.6615, 80.0255],
    ["trincomalee", "Ceypetco Trincomalee", "Central Road, Trincomalee", "Ceypetco", 8.5874, 81.2152],
    ["batticaloa", "Ceypetco Batticaloa", "Trinco Road, Batticaloa", "Ceypetco", 7.7170, 81.7000],
    ["badulla", "Ceypetco Badulla", "Bandarawela Road, Badulla", "Ceypetco", 6.9934, 81.0550],
    ["ratnapura", "Ceypetco Ratnapura", "Colombo Road, Ratnapura", "Ceypetco", 6.6828, 80.3992],
    ["galle", "Lanka IOC Galle", "Matara Road, Galle", "Lanka IOC", 6.0329, 80.2168],
    ["matara", "Ceypetco Matara", "Akuressa Road, Matara", "Ceypetco", 5.9549, 80.5550],
    ["hambantota", "Ceypetco Hambantota", "Tissa Road, Hambantota", "Ceypetco", 6.1241, 81.1185]
];

const fuels = [
    ["petrol92", 371, 30000],
    ["petrol95", 456, 18000],
    ["diesel", 363, 36000],
    ["superDiesel", 468, 16000]
];

const now = new Date();
const timestamp = date => ({ timestampValue: date.toISOString() });

function encode(value) {
    if (value && value.timestampValue) return value;
    if (value === null) return { nullValue: null };
    if (Array.isArray(value)) return { arrayValue: { values: value.map(encode) } };
    if (typeof value === "string") return { stringValue: value };
    if (typeof value === "boolean") return { booleanValue: value };
    if (typeof value === "number") {
        return Number.isInteger(value) ? { integerValue: String(value) } : { doubleValue: value };
    }
    return { mapValue: { fields: Object.fromEntries(Object.entries(value).map(([key, item]) => [key, encode(item)])) } };
}

function stationDocument(station, stationIndex) {
    const [id, name, address, operatorName, latitude, longitude] = station;
    const reports = fuels.map(([fuel, price, capacity], fuelIndex) => {
        const ratio = 0.38 + ((stationIndex * 11 + fuelIndex * 17) % 48) / 100;
        const stockLitres = Math.round(capacity * ratio);
        return {
            id: `demo-${id}-${fuel}-latest`, fuel,
            availability: ratio < 0.45 ? "limited" : "available",
            stockLitres, capacityLitres: capacity, pricePerLitre: price,
            reportedAt: timestamp(new Date(now.getTime() - (stationIndex % 4) * 18 * 60 * 1000)),
            source: "FuelSmart LK demo inventory", isStale: false
        };
    });

    const transactions = [];
    for (let day = 27; day >= 0; day--) {
        for (let fuelIndex = 0; fuelIndex < fuels.length; fuelIndex++) {
            const [fuel] = fuels[fuelIndex];
            const date = new Date(now);
            date.setUTCDate(date.getUTCDate() - day);
            date.setUTCHours(4 + fuelIndex * 2, 15, 0, 0);
            const litres = 620 + ((stationIndex * 173 + day * 97 + fuelIndex * 251) % 1380);
            transactions.push({
                id: `demo-${id}-sale-${fuel}-${day}`, kind: "sale", fuel, litres,
                occurredAt: timestamp(date), reference: `DEMO-SALE-${stationIndex + 1}-${fuelIndex + 1}-${day}`,
                status: "Confirmed"
            });
        }
        if (day % 7 === 0) {
            const fuelIndex = (stationIndex + day / 7) % fuels.length;
            const [fuel] = fuels[fuelIndex];
            const date = new Date(now);
            date.setUTCDate(date.getUTCDate() - day);
            date.setUTCHours(2, 30, 0, 0);
            transactions.push({
                id: `demo-${id}-delivery-${fuel}-${day}`, kind: "delivery", fuel, litres: 9000 + fuelIndex * 1000,
                occurredAt: timestamp(date), reference: `DEMO-DEL-${stationIndex + 1}-${day}`,
                status: "Confirmed"
            });
        }
    }

    return {
        id, fields: {
            name, address, operatorName, openingHours: "Open daily, 6:00 AM – 10:00 PM",
            phoneNumber: "+94 11 000 0000",
            sourceURL: operatorName === "Lanka IOC" ? "https://www.lankaioc.com/" : "https://ceypetco.gov.lk/",
            latitude, longitude, reports, transactions,
            dataClassification: "Demonstration data — verify operational details before travel",
            createdAt: timestamp(now), updatedAt: timestamp(now)
        }
    };
}

const stationDocs = stations.map(stationDocument);
const alertDocs = stationDocs.slice(0, 12).map((station, index) => {
    const report = station.fields.reports[index % station.fields.reports.length];
    const kind = index % 3 === 0 ? "price" : "restock";
    return {
        id: `demo-alert-${station.id}-${index}`,
        fields: {
            stationID: station.id, stationName: station.fields.name, kind, fuel: report.fuel,
            title: kind === "price" ? `${station.fields.name} price update` : `${station.fields.name} has been restocked`,
            message: kind === "price"
                ? `${report.fuel} demo price is LKR ${report.pricePerLitre} per litre.`
                : `${report.fuel} demo stock is now ${report.stockLitres} litres.`,
            createdAt: timestamp(new Date(now.getTime() - index * 45 * 60 * 1000)),
            isDemo: true
        }
    };
});

const databaseRoot = `projects/${projectID}/databases/(default)/documents`;
const writes = [
    ...stationDocs.map(doc => ({ update: { name: `${databaseRoot}/stations/${doc.id}`, fields: Object.fromEntries(Object.entries(doc.fields).map(([key, value]) => [key, encode(value)])) } })),
    ...alertDocs.map(doc => ({ update: { name: `${databaseRoot}/stationAlerts/${doc.id}`, fields: Object.fromEntries(Object.entries(doc.fields).map(([key, value]) => [key, encode(value)])) } }))
];

const response = await fetch(`https://firestore.googleapis.com/v1/projects/${projectID}/databases/(default)/documents:batchWrite`, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify({ writes })
});

if (!response.ok) throw new Error(`Firestore seed failed (${response.status}): ${await response.text()}`);
const result = await response.json();
const failures = (result.status ?? []).filter(status => status.code && status.code !== 0);
if (failures.length) throw new Error(`Firestore rejected ${failures.length} writes: ${JSON.stringify(failures)}`);

console.log(`Seeded ${stationDocs.length} demo stations, ${stationDocs.length * 112} sales, ${stationDocs.length * 4} deliveries, and ${alertDocs.length} alerts.`);
