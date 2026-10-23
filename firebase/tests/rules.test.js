// Emulator tests for firestore.rules. Run with `npm test` (needs Java 11+).
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, collection, query, where, getDocs } from 'firebase/firestore';

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
const as = (uid, phone) => env.authenticatedContext(uid, phone ? { phone_number: phone } : {}).firestore();

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
