// Emulator tests for firestore.rules. Run with `npm test` (needs Java 11+).
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, deleteDoc, collection, query, where, getDocs } from 'firebase/firestore';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-mashtal',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
  });
});

after(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/admin'), { phone: '+966500000001', name: 'Admin', city: 'riyadh', role: 'admin' });
    await setDoc(doc(db, 'users/n1owner'), { phone: '+966500000002', name: 'Rawdah', city: 'riyadh', role: 'nursery', partnerId: 'n1' });
    await setDoc(doc(db, 'users/n5owner'), { phone: '+966500000003', name: 'Fajr', city: 'riyadh', role: 'nursery', partnerId: 'n5' });
    await setDoc(doc(db, 'users/pr1owner'), { phone: '+966500000004', name: 'Abdullah', city: 'riyadh', role: 'professional', partnerId: 'pr1' });
    await setDoc(doc(db, 'professionals/pr1'), { nameEn: 'Abdullah', status: 'verified', services: ['planting'], cities: ['riyadh'] });
    await setDoc(doc(db, 'users/cust'), { phone: '+966500000005', name: 'Sara', city: 'riyadh', role: 'customer' });
    await setDoc(doc(db, 'plants/p01'), { nameAr: 'الغاف', nameEn: 'Ghaf tree' });
    await setDoc(doc(db, 'plants/p05'), { nameAr: 'الأثل', nameEn: 'Athel tamarisk' });
    await setDoc(doc(db, 'nurseries/n1'), { nameEn: 'Al Rawdah Nursery', status: 'verified' });
    await setDoc(doc(db, 'nurseries/n5'), { nameEn: 'Al Fajr Nursery', status: 'pending' });
    await setDoc(doc(db, 'listings/l1'), { nurseryId: 'n1', plantId: 'p01', price: 180, quantity: 12, hidden: false, public: true });
    await setDoc(doc(db, 'listings/l2'), { nurseryId: 'n5', plantId: 'p01', price: 170, quantity: 10, hidden: false, public: false });
  });
});

const guest = () => env.unauthenticatedContext().firestore();
// The app signs in to an Email/Password account named after the phone (TF-03).
const as = (uid, phone) =>
  env.authenticatedContext(uid, phone ? { email: `${phone.slice(1)}@phone.mashtal.app` } : {}).firestore();

describe('US-02 sign-up', () => {
  test('a new user can create their own customer profile', async () => {
    await assertSucceeds(setDoc(doc(as('new', '+966551112222'), 'users/new'), { phone: '+966551112222', name: 'Noura', city: 'riyadh', role: 'customer' }));
  });

  test('a user cannot make themselves admin or a nursery', async () => {
    await assertFails(setDoc(doc(as('new', '+966551112222'), 'users/new'), { phone: '+966551112222', name: 'X', city: 'riyadh', role: 'admin' }));
    await assertFails(updateDoc(doc(as('cust'), 'users/cust'), { role: 'admin' }));
  });

  test('a user cannot create a profile for another uid or phone', async () => {
    await assertFails(setDoc(doc(as('new', '+966551112222'), 'users/other'), { phone: '+966551112222', name: 'X', city: 'riyadh', role: 'customer' }));
    await assertFails(setDoc(doc(as('new', '+966551112222'), 'users/new'), { phone: '+966559999999', name: 'X', city: 'riyadh', role: 'customer' }));
  });

  test('users can read and edit only their own profile name and city', async () => {
    await assertSucceeds(updateDoc(doc(as('cust'), 'users/cust'), { name: 'Sara A', city: 'jeddah' }));
    await assertFails(getDoc(doc(as('cust'), 'users/n1owner')));
  });
});

describe('TF-03 partner accounts', () => {
  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'partnerAccounts/+966551113333'), { role: 'nursery', partnerId: 'n5' });
    });
  });

  test('a number the admin made a partner signs up with that role', async () => {
    const db = as('np', '+966551113333');
    await assertSucceeds(getDoc(doc(db, 'partnerAccounts/+966551113333')));
    await assertFails(setDoc(doc(db, 'users/np'), { phone: '+966551113333', name: 'N', city: 'riyadh', role: 'customer' }));
    await assertFails(setDoc(doc(db, 'users/np'), { phone: '+966551113333', name: 'N', city: 'riyadh', role: 'nursery', partnerId: 'n1' }));
    await assertSucceeds(setDoc(doc(db, 'users/np'), { phone: '+966551113333', name: 'N', city: 'riyadh', role: 'nursery', partnerId: 'n5' }));
  });

  test('an existing customer takes the role the admin gave later', async () => {
    const db = as('np', '+966551113333');
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'users/np'), { phone: '+966551113333', name: 'N', city: 'riyadh', role: 'customer' });
    });
    await assertFails(updateDoc(doc(db, 'users/np'), { role: 'admin' }));
    await assertSucceeds(updateDoc(doc(db, 'users/np'), { role: 'nursery', partnerId: 'n5' }));
  });

  test('only the admin writes partner accounts; others cannot read them', async () => {
    await assertFails(setDoc(doc(as('cust', '+966500000005'), 'partnerAccounts/+966500000005'), { role: 'admin' }));
    await assertFails(getDoc(doc(as('cust', '+966500000005'), 'partnerAccounts/+966551113333')));
    await assertSucceeds(setDoc(doc(as('admin', '+966500000001'), 'partnerAccounts/+966551114444'), { role: 'professional', partnerId: 'pr1' }));
    await assertSucceeds(deleteDoc(doc(as('admin', '+966500000001'), 'partnerAccounts/+966551114444')));
  });

  test('the admin uploads demo listings and removes them', async () => {
    const db = as('admin');
    await assertSucceeds(setDoc(doc(db, 'listings/l9'), { nurseryId: 'n1', plantId: 'p05', price: 50, quantity: 3, hidden: false, public: true }));
    await assertSucceeds(deleteDoc(doc(db, 'listings/l9')));
    await assertSucceeds(setDoc(doc(db, 'meta/seed'), { at: 1 }));
    await assertFails(setDoc(doc(as('cust'), 'meta/seed'), { at: 2 }));
  });
});

describe('US-16 reservations', () => {
  const item = { listingId: 'l1', plantId: 'p01', quantity: 2, price: 180 };
  const res = (over = {}) => ({
    customerId: 'cust', customerName: 'Sara', customerPhone: '0500000005', nurseryId: 'n1',
    items: [item], createdAt: '2026-11-17T10:00:00.000Z', status: 'pending', ...over,
  });

  test('a customer reserves for themselves, as pending', async () => {
    const db = as('cust', '+966500000005');
    await assertSucceeds(setDoc(doc(db, 'reservations/r1'), res()));
    await assertFails(setDoc(doc(db, 'reservations/r2'), res({ status: 'accepted' })));
    await assertFails(setDoc(doc(db, 'reservations/r3'), res({ customerId: 'other' })));
    await assertFails(setDoc(doc(db, 'reservations/r4'), res({ customerPhone: '0559999999' })));
    await assertFails(setDoc(doc(db, 'reservations/r5'), res({ items: [] })));
  });

  test('guests and partners cannot reserve', async () => {
    await assertFails(setDoc(doc(guest(), 'reservations/r1'), res()));
    await assertFails(setDoc(doc(as('n1owner', '+966500000002'), 'reservations/r1'), res({ customerId: 'n1owner', customerPhone: '0500000002' })));
  });

  test('the customer and that nursery read it; others cannot', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'reservations/r1'), res());
    });
    await assertSucceeds(getDoc(doc(as('cust'), 'reservations/r1')));
    await assertSucceeds(getDoc(doc(as('n1owner'), 'reservations/r1')));
    await assertFails(getDoc(doc(as('n5owner'), 'reservations/r1')));
    await assertSucceeds(getDocs(query(collection(as('cust'), 'reservations'), where('customerId', '==', 'cust'))));
    await assertSucceeds(getDocs(query(collection(as('n1owner'), 'reservations'), where('nurseryId', '==', 'n1'))));
  });
});

describe('US-17 accept or reject', () => {
  const pending = { customerId: 'cust', customerName: 'Sara', customerPhone: '0500000005', nurseryId: 'n1',
    items: [{ listingId: 'l1', plantId: 'p01', quantity: 1, price: 180 }], createdAt: '2026-11-17T10:00:00.000Z', status: 'pending' };
  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'reservations/r1'), pending);
    });
  });

  test('the nursery accepts with acceptedAt', async () => {
    await assertSucceeds(updateDoc(doc(as('n1owner'), 'reservations/r1'), { status: 'accepted', acceptedAt: '2026-11-17T11:00:00.000Z' }));
  });

  test('the nursery rejects with a known reason only', async () => {
    await assertFails(updateDoc(doc(as('n1owner'), 'reservations/r1'), { status: 'rejected', rejectReason: 'bored' }));
    await assertSucceeds(updateDoc(doc(as('n1owner'), 'reservations/r1'), { status: 'rejected', rejectReason: 'outOfStock' }));
  });

  test('other nurseries and the customer cannot decide; nor can items change', async () => {
    await assertFails(updateDoc(doc(as('n5owner'), 'reservations/r1'), { status: 'accepted', acceptedAt: 'x' }));
    await assertFails(updateDoc(doc(as('cust'), 'reservations/r1'), { status: 'accepted', acceptedAt: 'x' }));
    await assertFails(updateDoc(doc(as('n1owner'), 'reservations/r1'), { status: 'accepted', acceptedAt: 'x', items: [] }));
  });

  test('a decided reservation cannot be decided again', async () => {
    await updateDoc(doc(as('n1owner'), 'reservations/r1'), { status: 'accepted', acceptedAt: 'x' });
    await assertFails(updateDoc(doc(as('n1owner'), 'reservations/r1'), { status: 'rejected', rejectReason: 'other' }));
  });
});

describe('US-03 verification', () => {
  test('guests see verified nurseries but not pending ones', async () => {
    await assertSucceeds(getDoc(doc(guest(), 'nurseries/n1')));
    await assertFails(getDoc(doc(guest(), 'nurseries/n5')));
  });

  test('a pending nursery can see its own record', async () => {
    await assertSucceeds(getDoc(doc(as('n5owner'), 'nurseries/n5')));
  });

  test('only the admin can verify a nursery', async () => {
    await assertFails(updateDoc(doc(as('cust'), 'nurseries/n5'), { status: 'verified' }));
    await assertFails(updateDoc(doc(as('n5owner'), 'nurseries/n5'), { status: 'verified' }));
    await assertSucceeds(updateDoc(doc(as('admin'), 'nurseries/n5'), { status: 'verified' }));
  });

  test('new nurseries must start as pending', async () => {
    await assertFails(setDoc(doc(as('admin'), 'nurseries/n9'), { nameEn: 'New', status: 'verified' }));
    await assertSucceeds(setDoc(doc(as('admin'), 'nurseries/n9'), { nameEn: 'New', status: 'pending' }));
  });

  test('listings of a pending nursery are hidden from customers', async () => {
    await assertFails(getDoc(doc(as('cust'), 'listings/l2')));
    await assertSucceeds(getDocs(query(collection(guest(), 'listings'), where('public', '==', true))));
    await assertFails(getDocs(collection(guest(), 'listings')));
  });
});

describe('US-04 server-side roles (NFR-05)', () => {
  test('a customer cannot write admin or nursery data', async () => {
    await assertFails(setDoc(doc(as('cust'), 'plants/p99'), { nameEn: 'Fake' }));
    await assertFails(setDoc(doc(as('cust'), 'listings/x'), { nurseryId: 'n1', plantId: 'p01', price: 1, quantity: 1, hidden: false, public: true }));
    await assertFails(setDoc(doc(as('cust'), 'priceRanges/pruning'), { min: 1, max: 2 }));
  });
});

describe('US-06 nursery listings', () => {
  const listing = (over = {}) => ({ nurseryId: 'n1', plantId: 'p05', price: 140, quantity: 6, hidden: false, public: true, ...over });

  test('a verified nursery adds a listing for a plant in the knowledge base', async () => {
    await assertSucceeds(setDoc(doc(as('n1owner'), 'listings/new'), listing()));
  });

  test('the plant must exist and values must be valid', async () => {
    await assertFails(setDoc(doc(as('n1owner'), 'listings/new'), listing({ plantId: 'nope' })));
    await assertFails(setDoc(doc(as('n1owner'), 'listings/new'), listing({ price: 0 })));
    await assertFails(setDoc(doc(as('n1owner'), 'listings/new'), listing({ quantity: -1 })));
  });

  test('a nursery cannot list for another nursery', async () => {
    await assertFails(setDoc(doc(as('n5owner'), 'listings/new'), listing({ nurseryId: 'n1' })));
  });

  test('a pending nursery cannot make its listing public', async () => {
    await assertFails(setDoc(doc(as('n5owner'), 'listings/new'), listing({ nurseryId: 'n5', public: true })));
    await assertSucceeds(setDoc(doc(as('n5owner'), 'listings/new'), listing({ nurseryId: 'n5', public: false })));
  });

  test('hiding a listing or setting quantity to 0 is allowed; hidden listings are not public', async () => {
    await assertSucceeds(updateDoc(doc(as('n1owner'), 'listings/l1'), { quantity: 0 }));
    await assertFails(updateDoc(doc(as('n1owner'), 'listings/l1'), { hidden: true }));
    await assertSucceeds(updateDoc(doc(as('n1owner'), 'listings/l1'), { hidden: true, public: false }));
  });

  test('a nursery cannot edit another nursery\'s listing', async () => {
    await assertFails(updateDoc(doc(as('n5owner'), 'listings/l1'), { price: 1 }));
  });
});

describe('review feedback', () => {
  const newPlant = (extra = {}) => ({ nameAr: 'نبتة', nameEn: 'Test plant', guideBacked: false, addedBy: 'n1', ...extra });

  test('a nursery adds a plant that is not in the list, marked as not guide-backed', async () => {
    await assertSucceeds(setDoc(doc(as('n1owner'), 'plants/c1'), newPlant()));
    await assertFails(setDoc(doc(as('n1owner'), 'plants/c2'), newPlant({ guideBacked: true })));
    await assertFails(setDoc(doc(as('n1owner'), 'plants/c3'), newPlant({ addedBy: 'n5' })));
    await assertFails(setDoc(doc(as('cust'), 'plants/c4'), newPlant()));
  });

  test('only the nursery that added a plant, or the admin, can delete it', async () => {
    await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'plants/c1'), newPlant()));
    await assertFails(deleteDoc(doc(as('n5owner'), 'plants/c1')));
    await assertFails(deleteDoc(doc(as('n1owner'), 'plants/p01')));
    await assertSucceeds(deleteDoc(doc(as('n1owner'), 'plants/c1')));
    await assertSucceeds(deleteDoc(doc(as('admin'), 'plants/p05')));
  });

  test('a nursery deletes its own listing only', async () => {
    await assertFails(deleteDoc(doc(as('n5owner'), 'listings/l1')));
    await assertSucceeds(deleteDoc(doc(as('n1owner'), 'listings/l1')));
  });

  test('a listing can carry the nursery\'s own photo', async () => {
    await assertSucceeds(updateDoc(doc(as('n1owner'), 'listings/l1'), { photo: '/9j/4AAQSkZJRg==' }));
  });

  test('the admin edits and deletes partners and price ranges', async () => {
    await assertSucceeds(updateDoc(doc(as('admin'), 'nurseries/n1'), { nameEn: 'Renamed' }));
    await assertSucceeds(deleteDoc(doc(as('admin'), 'professionals/pr1')));
    await assertSucceeds(setDoc(doc(as('admin'), 'priceRanges/pruning'), { min: 60, max: 300 }));
    await assertFails(setDoc(doc(as('n1owner'), 'priceRanges/pruning'), { min: 60, max: 300 }));
  });

  test('a professional edits only their own services and cities', async () => {
    await assertSucceeds(updateDoc(doc(as('pr1owner'), 'professionals/pr1'), { services: ['planting', 'treatment'], cities: ['riyadh', 'jeddah'] }));
    await assertFails(updateDoc(doc(as('pr1owner'), 'professionals/pr1'), { status: 'verified', nameEn: 'X' }));
    await assertFails(updateDoc(doc(as('pr1owner'), 'professionals/pr1'), { services: [] }));
  });
});

describe('US-14 plant data edits', () => {
  const edit = (editorId) => ({ plantId: 'p01', field: 'water', oldValue: 'low', newValue: 'medium', editorId, editorName: 'Admin', at: '2026-11-02T10:00:00Z' });

  test('the admin edits a plant and logs the change as themselves', async () => {
    await assertSucceeds(updateDoc(doc(as('admin'), 'plants/p01'), { water: 'medium' }));
    await assertSucceeds(setDoc(doc(as('admin'), 'plantEdits/e1'), edit('admin')));
  });

  test('nobody else edits plants or writes the log, and the log cannot be changed', async () => {
    await assertFails(updateDoc(doc(as('n1owner'), 'plants/p01'), { water: 'medium' }));
    await assertFails(setDoc(doc(as('cust'), 'plantEdits/e2'), edit('cust')));
    await assertFails(setDoc(doc(as('admin'), 'plantEdits/e3'), edit('someoneElse')));
    await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'plantEdits/e4'), edit('admin')));
    await assertFails(updateDoc(doc(as('admin'), 'plantEdits/e4'), { newValue: 'high' }));
    await assertFails(deleteDoc(doc(as('admin'), 'plantEdits/e4')));
    await assertFails(getDoc(doc(as('cust'), 'plantEdits/e4')));
  });
});

describe('US-21 My Garden', () => {
  const plant = (extra = {}) => ({ ownerId: 'cust', plantId: 'p01', addedAt: '2026-11-20T10:00:00Z', source: 'manual', quantity: 1, ...extra });

  test('a customer adds a plant by hand to their own garden', async () => {
    await assertSucceeds(setDoc(doc(as('cust'), 'garden/g1'), plant()));
    await assertFails(setDoc(doc(as('cust'), 'garden/g2'), plant({ ownerId: 'someoneElse' })));
    await assertFails(setDoc(doc(as('cust'), 'garden/g3'), plant({ plantId: 'nope' })));
    await assertFails(setDoc(doc(as('n1owner'), 'garden/g4'), plant({ ownerId: 'n1owner' })));
  });

  test('only the owner reads it or records a watering', async () => {
    await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'garden/g1'), plant()));
    await assertSucceeds(getDocs(query(collection(as('cust'), 'garden'), where('ownerId', '==', 'cust'))));
    await assertFails(getDoc(doc(as('n1owner'), 'garden/g1')));
    await assertSucceeds(updateDoc(doc(as('cust'), 'garden/g1'), { lastWateredAt: '2026-11-21T08:00:00Z' }));
    await assertFails(updateDoc(doc(as('cust'), 'garden/g1'), { plantId: 'p05' }));
    await assertFails(deleteDoc(doc(as('n1owner'), 'garden/g1')));
    await assertSucceeds(deleteDoc(doc(as('cust'), 'garden/g1')));
  });

  test('the owner sets where it lives and says the soil is still moist', async () => {
    await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'garden/g1'), plant()));
    await assertSucceeds(setDoc(doc(as('cust'), 'garden/g2'), plant({ home: 'smallPot' })));
    await assertFails(setDoc(doc(as('cust'), 'garden/g3'), plant({ home: 'roof' })));
    await assertSucceeds(updateDoc(doc(as('cust'), 'garden/g1'), { home: 'bigPot' }));
    await assertFails(updateDoc(doc(as('cust'), 'garden/g1'), { home: 'roof' }));
    await assertSucceeds(updateDoc(doc(as('cust'), 'garden/g1'), { lastCheckedAt: '2026-11-21T08:00:00Z', pace: 1.15 }));
    await assertFails(updateDoc(doc(as('cust'), 'garden/g1'), { lastCheckedAt: '2026-11-22T08:00:00Z', pace: 5 }));
    await assertFails(updateDoc(doc(as('n1owner'), 'garden/g1'), { home: 'indoor' }));
  });
});

describe('US-20 picked up into My Garden', () => {
  const res = (status) => ({ customerId: 'cust', customerName: 'Sara', customerPhone: '0500000005', nurseryId: 'n1', items: [{ listingId: 'l1', plantId: 'p01', quantity: 1, price: 180 }], createdAt: '2026-11-20T10:00:00Z', status, acceptedAt: '2026-11-20T11:00:00Z' });
  const fromPickup = (extra = {}) => ({ ownerId: 'cust', plantId: 'p01', addedAt: '2026-11-21T10:00:00Z', source: 'pickup', quantity: 1, reservationId: 'r1', nurseryId: 'n1', ...extra });

  test('the nursery marks only an accepted reservation picked up', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'reservations/r1'), res('accepted'));
      await setDoc(doc(ctx.firestore(), 'reservations/r2'), res('pending'));
    });
    await assertFails(updateDoc(doc(as('n5owner'), 'reservations/r1'), { status: 'pickedUp', pickedUpAt: '2026-11-21T10:00:00Z' }));
    await assertFails(updateDoc(doc(as('cust'), 'reservations/r1'), { status: 'pickedUp', pickedUpAt: '2026-11-21T10:00:00Z' }));
    await assertFails(updateDoc(doc(as('n1owner'), 'reservations/r2'), { status: 'pickedUp', pickedUpAt: '2026-11-21T10:00:00Z' }));
    await assertSucceeds(updateDoc(doc(as('n1owner'), 'reservations/r1'), { status: 'pickedUp', pickedUpAt: '2026-11-21T10:00:00Z' }));
  });

  test('the customer adds plants only from their own picked-up reservation', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'reservations/r1'), res('pickedUp'));
      await setDoc(doc(ctx.firestore(), 'reservations/r2'), res('accepted'));
    });
    await assertFails(setDoc(doc(as('cust'), 'garden/g2'), fromPickup({ reservationId: 'r2' })));
    await assertFails(setDoc(doc(as('cust'), 'garden/g3'), fromPickup({ nurseryId: 'n5' })));
    await assertSucceeds(setDoc(doc(as('cust'), 'garden/g1'), fromPickup()));
    await assertSucceeds(updateDoc(doc(as('cust'), 'garden/g1'), { removedAt: '2026-11-22T10:00:00Z' }));
  });
});

describe('US-22 plant history', () => {
  const entry = (extra = {}) => ({ ownerId: 'cust', gardenPlantId: 'g1', kind: 'note', at: '2026-11-21T10:00:00Z', text: 'Moved it', ...extra });
  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'garden/g1'), { ownerId: 'cust', plantId: 'p01', addedAt: '2026-11-20T10:00:00Z', source: 'manual', quantity: 1 });
      await setDoc(doc(ctx.firestore(), 'garden/g9'), { ownerId: 'someoneElse', plantId: 'p01', addedAt: '2026-11-20T10:00:00Z', source: 'manual', quantity: 1 });
    });
  });

  test('the owner adds waterings and notes to their own plants', async () => {
    await assertSucceeds(setDoc(doc(as('cust'), 'history/h1'), entry()));
    await assertSucceeds(setDoc(doc(as('cust'), 'history/h2'), { ownerId: 'cust', gardenPlantId: 'g1', kind: 'watered', at: '2026-11-21T10:00:00Z' }));
    await assertFails(setDoc(doc(as('cust'), 'history/h3'), entry({ gardenPlantId: 'g9' })));
    await assertFails(setDoc(doc(as('cust'), 'history/h4'), entry({ kind: 'proFeedback' })));
    await assertFails(setDoc(doc(as('cust'), 'history/h5'), entry({ text: 'x'.repeat(281) })));
  });

  test('the owner adds growth photos, size-limited, only as photo entries', async () => {
    const photo = { ownerId: 'cust', gardenPlantId: 'g1', kind: 'photo', at: '2026-11-21T10:00:00Z', photo: 'abc' };
    await assertSucceeds(setDoc(doc(as('cust'), 'history/p1'), photo));
    await assertFails(setDoc(doc(as('cust'), 'history/p2'), { ...photo, photo: 'x'.repeat(400001) }));
    await assertFails(setDoc(doc(as('cust'), 'history/p3'), { ownerId: 'cust', gardenPlantId: 'g1', kind: 'photo', at: '2026-11-21T10:00:00Z' }));
    await assertFails(setDoc(doc(as('cust'), 'history/p4'), entry({ photo: 'abc' })));
    await assertFails(setDoc(doc(as('cust'), 'history/p5'), { ...photo, gardenPlantId: 'g9' }));
  });

  test('history is private and cannot be rewritten', async () => {
    await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'history/h1'), entry()));
    await assertFails(getDoc(doc(as('n1owner'), 'history/h1')));
    await assertFails(updateDoc(doc(as('cust'), 'history/h1'), { text: 'changed' }));
    await assertSucceeds(getDocs(query(collection(as('cust'), 'history'), where('ownerId', '==', 'cust'))));
  });
});

describe('US-19 notice times', () => {
  test('a rejection records when it happened', async () => {
    await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'reservations/r1'), {
      customerId: 'cust', customerName: 'Sara', customerPhone: '0500000005', nurseryId: 'n1',
      items: [{ listingId: 'l1', plantId: 'p01', quantity: 1, price: 180 }], createdAt: '2026-11-20T10:00:00Z', status: 'pending',
    }));
    await assertSucceeds(updateDoc(doc(as('n1owner'), 'reservations/r1'), { status: 'rejected', rejectReason: 'other', rejectedAt: '2026-11-20T11:00:00Z' }));
  });
});
