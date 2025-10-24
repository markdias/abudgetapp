import express from 'express';
import fs from 'fs';
import path from 'path';
import bodyParser from 'body-parser';
import cors from 'cors';
import { fileURLToPath } from 'url';
import { dirname } from 'path';
import swaggerUi from 'swagger-ui-express';
import YAML from 'yamljs';

const app = express();
const PORT = 3000;

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

app.use(bodyParser.json());
app.use(cors()); // Add CORS middleware

// Load Swagger document
const swaggerDocument = YAML.load(path.join(__dirname, 'swagger.yaml'));

// Serve Swagger UI
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerDocument));

// Add helper functions at the top
const ensureAccountShape = (account) => ({
  ...account,
  pots: account.pots || [],
  scheduled_payments: account.scheduled_payments || [],
  expenses: account.expenses || [],
  incomes: account.incomes || [],
  transactions: account.transactions || []
});

const computeNextTransactionId = (accounts) =>
  accounts.reduce((maxId, account) => {
    const accountMax = (account.transactions || []).reduce(
      (max, transaction) => Math.max(max, Number(transaction.id) || 0),
      0
    );
    return Math.max(maxId, accountMax);
  }, 0);

const normalizeData = (data) => {
  const normalizedAccounts = (data.accounts || []).map(ensureAccountShape);
  const nextTransactionId = Number.isInteger(data.nextTransactionId)
    ? data.nextTransactionId
    : computeNextTransactionId(normalizedAccounts) + 1;

  return {
    ...data,
    accounts: normalizedAccounts,
    scheduled_incomes: data.scheduled_incomes || [],
    income_schedules: data.income_schedules || [],
    nextTransactionId
  };
};

// Update the helper functions for better error handling and data validation
const readData = () => {
  const filePath = path.join(__dirname, 'budget_data.json');
  return new Promise((resolve, reject) => {
    fs.readFile(filePath, 'utf8', (err, data) => {
      if (err) {
        reject(new Error(`Error reading file: ${err.message}`));
        return;
      }
      try {
        // Ensure we have data
        if (!data || data.trim() === '') {
          console.error('Empty or invalid data file');
          // Return a default structure if file is empty
          resolve({
            accounts: [],
            scheduled_incomes: [],
            income_schedules: [],
            nextTransactionId: 1
          });
          return;
        }

        const budgetData = JSON.parse(data.trim());

        // Validate the structure
        if (!budgetData || typeof budgetData !== 'object') {
          throw new Error('Invalid JSON structure');
        }

        resolve(normalizeData(budgetData));
      } catch (error) {
        console.error('Error parsing JSON:', error);
        reject(new Error(`Invalid JSON format: ${error.message}`));
      }
    });
  });
};

const writeData = async (data) => {
  const filePath = path.join(__dirname, 'budget_data.json');
  
  // Validate data before writing
  if (!data || typeof data !== 'object') {
    throw new Error('Invalid data structure');
  }

  // Ensure all required properties exist
  const validatedData = normalizeData(data);

  return new Promise((resolve, reject) => {
    // Pretty print JSON with 2 space indentation
    const jsonString = JSON.stringify(validatedData, null, 2);
    fs.writeFile(filePath, jsonString, 'utf8', (err) => {
      if (err) {
        reject(err);
        return;
      }
      resolve();
    });
  });
};

// Add this new endpoint near the top with other GET endpoints
app.get('/accounts', async (req, res) => {
  try {
    const data = await readData();
    const regularAccounts = data.accounts.filter(acc => 
      acc.type !== 'savings' && acc.type !== 'investment'
    );
    res.status(200).json(regularAccounts);
  } catch (error) {
    console.error('Error fetching accounts:', error);
    res.status(500).json({ error: 'Failed to fetch accounts' });
  }
});

app.post('/add-account', (req, res) => {
  const newAccount = req.body;
  console.log('Received new account:', newAccount); // Log the received account data
  const filePath = path.join(__dirname, 'budget_data.json');

  fs.readFile(filePath, 'utf8', (err, data) => {
    if (err) {
      console.error('Error reading file:', err); // Log the error
      return res.status(500).send('Error reading file');
    }

    console.log('File read successfully'); // Log file read success
    const budgetData = JSON.parse(data);
    console.log('Current budget data:', budgetData); // Log current budget data

    const nextId = budgetData.accounts.reduce((maxId, account) => Math.max(maxId, account.id || 0), 0) + 1;
    newAccount.id = nextId; // Assign the next available ID
    newAccount.pots = [];
    newAccount.scheduled_payments = [];
    newAccount.credit_limit = newAccount.type === 'credit' ? 1000 : undefined; // Add credit_limit for credit accounts
    newAccount.accountType = newAccount.accountType || 'personal'; // Default to personal
    console.log('Adding account with type:', newAccount.accountType);
    budgetData.accounts.push(newAccount);
    console.log('Updated budget data:', budgetData); // Log updated budget data

    fs.writeFile(filePath, JSON.stringify(budgetData, null, 2), 'utf8', (err) => {
      if (err) {
        console.error('Error writing file:', err); // Log the error
        return res.status(500).send('Error writing file');
      }

      console.log('Account added successfully'); // Log success message
      res.status(200).send(newAccount);
    });
  });
});

// Update the add-pot endpoint to include excludeFromReset
app.post('/add-pot', (req, res) => {
  const { accountId, pot } = req.body;
  const filePath = path.join(__dirname, 'budget_data.json');

  fs.readFile(filePath, 'utf8', (err, data) => {
    if (err) return res.status(500).send('Error reading file');

    try {
      const budgetData = JSON.parse(data);
      const account = budgetData.accounts.find(acc => acc.id === accountId);
      
      if (!account) return res.status(404).send('Account not found');

      if (!account.pots) account.pots = [];

      // Generate new pot ID
      const maxPotId = budgetData.accounts.reduce((max, acc) => {
        const accMax = acc.pots?.reduce((m, p) => Math.max(m, p.id || 0), 0) || 0;
        return Math.max(max, accMax);
      }, 0);

      const newPot = {
        id: maxPotId + 1,
        name: pot.name,
        balance: pot.balance,
        excludeFromReset: false, // Add default value
        scheduled_payments: []
      };
      
      account.pots.push(newPot);
      
      fs.writeFile(filePath, JSON.stringify(budgetData, null, 2), 'utf8', (err) => {
        if (err) return res.status(500).send('Error writing file');
        res.status(200).send(newPot);
      });
    } catch (error) {
      res.status(500).send('Error processing data');
    }
  });
});

// Update the update-pot endpoint to ensure excludeFromReset is handled correctly
app.put('/update-pot', (req, res) => {
  const { originalAccountId, originalPot, updatedPot } = req.body;
  console.log('Updating pot:', { originalAccountId, originalPot, updatedPot }); // Debug log
  
  const filePath = path.join(__dirname, 'budget_data.json');

  fs.readFile(filePath, 'utf8', (err, data) => {
    if (err) return res.status(500).send('Error reading file');

    try {
      const budgetData = JSON.parse(data);
      const account = budgetData.accounts.find(acc => acc.id === originalAccountId);
      
      if (!account) {
        return res.status(404).send('Account not found');
      }

      const potIndex = account.pots.findIndex(p => p.name === originalPot.name);
      if (potIndex === -1) {
        return res.status(404).send('Pot not found');
      }

      // Update the pot with new values while preserving the ID and scheduled payments
      account.pots[potIndex] = {
        ...account.pots[potIndex],
        name: updatedPot.name,
        balance: parseFloat(updatedPot.balance),
        excludeFromReset: Boolean(updatedPot.excludeFromReset)
      };

      fs.writeFile(filePath, JSON.stringify(budgetData, null, 2), 'utf8', (err) => {
        if (err) return res.status(500).send('Error writing file');
        res.status(200).json(account.pots[potIndex]);
      });
    } catch (error) {
      console.error('Error updating pot:', error);
      res.status(500).send('Error processing data: ' + error.message);
    }
  });
});

app.delete('/delete-pot', (req, res) => {
  const { potName, accountName } = req.body;
  const filePath = path.join(__dirname, 'budget_data.json');

  fs.readFile(filePath, 'utf8', (err, data) => {
    if (err) {
      console.error('Error reading file:', err);
      return res.status(500).send('Error reading file');
    }

    try {
      const budgetData = JSON.parse(data);
      const account = budgetData.accounts.find(acc => acc.name === accountName);
      
      if (!account) {
        return res.status(404).send('Account not found');
      }

      const potIndex = account.pots.findIndex(pot => pot.name === potName);
      if (potIndex === -1) {
        return res.status(404).send('Pot not found');
      }

      // Remove the pot from the account
      account.pots.splice(potIndex, 1);
      
      fs.writeFile(filePath, JSON.stringify(budgetData, null, 2), 'utf8', (err) => {
        if (err) {
          console.error('Error writing file:', err);
          return res.status(500).send('Error writing file');
        }
        res.status(200).send({ message: 'Pot deleted successfully' });
      });
    } catch (error) {
      console.error('Error processing data:', error);
      res.status(500).send('Error processing data');
    }
  });
});

// Update the card order endpoint to handle array of IDs
app.post('/update-card-order', async (req, res) => {
  const { cardIds } = req.body;
  
  if (!Array.isArray(cardIds)) {
    return res.status(400).json({ error: 'cardIds must be an array' });
  }

  try {
    const data = await readData();
    
    // Create a map for quick lookups
    const accountMap = new Map(data.accounts.map(acc => [acc.id, acc]));
    
    // Create new sorted array while preserving all account data
    const sortedAccounts = cardIds
      .map(id => accountMap.get(id))
      .filter(Boolean);
    
    // Add any accounts that weren't in the cardIds array at the end
    const remainingAccounts = data.accounts.filter(acc => !cardIds.includes(acc.id));
    
    // Update accounts array with new order
    data.accounts = [...sortedAccounts, ...remainingAccounts];
    
    await writeData(data);
    
    res.status(200).json({
      success: true,
      message: 'Card order updated successfully',
      accounts: data.accounts
    });
  } catch (error) {
    console.error('Error updating card order:', error);
    res.status(500).json({ error: 'Failed to update card order' });
  }
});

app.delete('/delete-scheduled-payment', (req, res) => {
  const { accountId, paymentName, paymentDate, potName } = req.body;
  const filePath = path.join(__dirname, 'budget_data.json');

  fs.readFile(filePath, 'utf8', (err, data) => {
    if (err) {
      console.error('Error reading file:', err);
      return res.status(500).send('Error reading file');
    }

    try {
      const budgetData = JSON.parse(data);
      const account = budgetData.accounts.find(acc => acc.id === accountId);
      
      if (!account) {
        return res.status(404).send('Account not found');
      }

      if (potName) {
        // Delete payment from pot
        const pot = account.pots?.find(p => p.name === potName);
        if (!pot || !pot.scheduled_payments) {
          return res.status(404).send('Pot or payments not found');
        }

        const paymentIndex = pot.scheduled_payments.findIndex(p => 
          p.name === paymentName && p.date === paymentDate
        );

        if (paymentIndex === -1) {
          return res.status(404).send('Payment not found in pot');
        }

        // Remove the payment
        pot.scheduled_payments.splice(paymentIndex, 1);
      } else {
        // Delete payment from account
        if (!account.scheduled_payments) {
          return res.status(404).send('No scheduled payments found');
        }
        
        const paymentIndex = account.scheduled_payments.findIndex(p => 
          p.name === paymentName && p.date === paymentDate
        );

        if (paymentIndex === -1) {
          return res.status(404).send('Payment not found');
        }

        // Remove the payment
        account.scheduled_payments.splice(paymentIndex, 1);
      }
      
      fs.writeFile(filePath, JSON.stringify(budgetData, null, 2), 'utf8', (err) => {
        if (err) {
          console.error('Error writing file:', err);
          return res.status(500).send('Error writing file');
        }
        res.status(200).send({ message: 'Payment deleted successfully' });
      });
    } catch (error) {
      console.error('Error processing data:', error);
      res.status(500).send('Error processing data');
    }
  });
});

app.put('/update-scheduled-payment', (req, res) => {
  const { accountId, originalPayment, updatedPayment } = req.body;
  if (!updatedPayment.company) {
    return res.status(400).send('Company name is required');
  }
  
  const filePath = path.join(__dirname, 'budget_data.json');

  fs.readFile(filePath, 'utf8', (err, data) => {
    if (err) {
      return res.status(500).send('Error reading file');
    }

    try {
      const budgetData = JSON.parse(data);
      const account = budgetData.accounts.find(acc => acc.id === accountId);
      
      if (!account) {
        return res.status(404).send('Account not found');
      }

      // If the payment has a potName, update in the pot
      if (updatedPayment.potName) {
        const pot = account.pots.find(p => p.name === updatedPayment.potName);
        if (!pot) {
          return res.status(404).send('Pot not found');
        }

        // Initialize pot's scheduled_payments if needed
        if (!pot.scheduled_payments) {
          pot.scheduled_payments = [];
        }

        // If payment was previously in a different pot or account, remove it
        if (originalPayment.potName) {
          const originalPot = account.pots.find(p => p.name === originalPayment.potName);
          if (originalPot && originalPot.scheduled_payments) {
            const paymentIndex = originalPot.scheduled_payments.findIndex(
              p => p.name === originalPayment.name && p.date === originalPayment.date
            );
            if (paymentIndex !== -1) {
              originalPot.scheduled_payments.splice(paymentIndex, 1);
            }
          }
        } else {
          // Remove from account's scheduled payments if it was there
          const paymentIndex = account.scheduled_payments.findIndex(
            p => p.name === originalPayment.name && p.date === originalPayment.date
          );
          if (paymentIndex !== -1) {
            account.scheduled_payments.splice(paymentIndex, 1);
          }
        }

        // Add to new pot
        pot.scheduled_payments.push(updatedPayment);
      } else {
        // Update in account's scheduled payments
        const paymentIndex = account.scheduled_payments.findIndex(
          payment => payment.name === originalPayment.name && payment.date === originalPayment.date
        );

        if (paymentIndex === -1) {
          return res.status(404).send('Payment not found');
        }

        account.scheduled_payments[paymentIndex] = updatedPayment;
      }
      
      fs.writeFile(filePath, JSON.stringify(budgetData, null, 2), 'utf8', (err) => {
        if (err) {
          return res.status(500).send('Error writing file');
        }
        res.status(200).send(updatedPayment);
      });
    } catch (error) {
      res.status(500).send('Error processing data');
    }
  });
});

// Modify the add-expense endpoint to remove isScheduled flag
app.post('/add-expense', (req, res) => {
  const { accountId, expense } = req.body;
  const filePath = path.join(__dirname, 'budget_data.json');

  fs.readFile(filePath, 'utf8', (err, data) => {
    if (err) {
      console.error('Error reading file:', err);
      return res.status(500).send('Error reading file');
    }

    try {
      const budgetData = JSON.parse(data);
      const account = budgetData.accounts.find(acc => acc.id === accountId);
      
      if (!account) {
        return res.status(404).send('Account not found');
      }

      if (!account.expenses) {
        account.expenses = [];
      }

      // Create new expense without isScheduled flag
      const newExpense = {
        ...expense,
        id: Date.now(),
        date: new Date().toISOString()
      };
      
      account.expenses.push(newExpense);

      fs.writeFile(filePath, JSON.stringify(budgetData, null, 2), 'utf8', (err) => {
        if (err) {
          console.error('Error writing file:', err);
          return res.status(500).send('Error writing file');
        }
        res.status(200).json(newExpense);
      });
    } catch (error) {
      console.error('Error processing data:', error);
      res.status(500).send('Error processing data: ' + error.message);
    }
  });
});

// Add new endpoint to get pending expenses
app.get('/group-pending-expenses', (req, res) => {
  const filePath = path.join(__dirname, 'budget_data.json');
  
  fs.readFile(filePath, 'utf8', (err, data) => {
    if (err) {
      return res.status(500).send('Error reading file');
    }
    
    try {
      const budgetData = JSON.parse(data);
      const groupedExpenses = [];

      // Go through each account and collect unscheduled expenses
      budgetData.accounts.forEach(account => {
        if (account.expenses) {
          const pendingExpenses = account.expenses
            .filter(expense => !expense.isScheduled)
            .map(expense => ({
              ...expense,
              accountId: account.id,
              accountName: account.name
            }));

          if (pendingExpenses.length > 0) {
            groupedExpenses.push({
              accountId: account.id,
              accountName: account.name,
              totalAmount: pendingExpenses.reduce((sum, exp) => sum + exp.amount, 0),
              expenses: pendingExpenses
            });
          }
        }
      });

      res.status(200).json(groupedExpenses);
    } catch (error) {
      res.status(500).send('Error processing data');
    }
  });
});

// Add income to account
app.post('/add-income', (req, res) => {
  const { accountId, income } = req.body;
  const filePath = path.join(__dirname, 'budget_data.json');

  fs.readFile(filePath, 'utf8', (err, data) => {
    if (err) {
      console.error('Error reading file:', err);
      return res.status(500).send('Error reading file');
    }

    try {
      const budgetData = JSON.parse(data);
      const account = budgetData.accounts.find(acc => acc.id === accountId);
      
      if (!account) {
        return res.status(404).send('Account not found');
      }

      if (!account.incomes) {
        account.incomes = [];
      }

      const newIncome = {
        ...income,
        id: Date.now(),
        date: new Date().toISOString()
      };
      
      // Only add the income to the array, don't update the balance
      account.incomes.push(newIncome);
      
      fs.writeFile(filePath, JSON.stringify(budgetData, null, 2), 'utf8', (err) => {
        if (err) {
          return res.status(500).send('Error writing file');
        }
        res.status(200).send(newIncome);
      });
    } catch (error) {
      res.status(500).send('Error processing data: ' + error.message);
    }
  });
});

app.post('/add-transaction', async (req, res) => {
  const { accountId, transaction } = req.body;

  if (typeof accountId !== 'number' || !transaction) {
    return res.status(400).json({ error: 'accountId and transaction are required' });
  }

  const { amount, description, date, merchant, isCredit } = transaction;
  const numericAmount = Number(amount);
  if (!Number.isFinite(numericAmount)) {
    return res.status(400).json({ error: 'Transaction amount must be a number' });
  }
  if (typeof description !== 'string' || description.trim() === '') {
    return res.status(400).json({ error: 'Transaction description is required' });
  }
  if (typeof isCredit !== 'boolean') {
    return res.status(400).json({ error: 'Transaction isCredit flag is required' });
  }

  const entryDate = typeof date === 'string' && date.trim() !== '' ? date : new Date().toISOString();
  const merchantValue = typeof merchant === 'string' && merchant.trim() !== '' ? merchant.trim() : null;

  try {
    const data = await readData();
    const accountIndex = data.accounts.findIndex((acc) => acc.id === accountId);

    if (accountIndex === -1) {
      return res.status(404).json({ error: 'Account not found' });
    }

    const account = data.accounts[accountIndex];
    if (!Array.isArray(account.transactions)) {
      account.transactions = [];
    }

    const transactionId = Number.isInteger(data.nextTransactionId)
      ? data.nextTransactionId
      : computeNextTransactionId(data.accounts) + 1;
    data.nextTransactionId = transactionId + 1;

    const newTransaction = {
      id: transactionId,
      amount: numericAmount,
      description: description.trim(),
      date: entryDate,
      merchant: merchantValue,
      isCredit
    };

    account.transactions.push(newTransaction);
    const signedAmount = isCredit ? numericAmount : -numericAmount;
    account.balance = Number(account.balance || 0) + signedAmount;
    data.accounts[accountIndex] = account;

    await writeData(data);
    res.status(200).json(newTransaction);
  } catch (error) {
    console.error('Error adding transaction:', error);
    res.status(500).json({ error: 'Failed to add transaction' });
  }
});

app.put('/update-transaction', async (req, res) => {
  const { accountId, transactionId, transaction } = req.body;

  if (typeof accountId !== 'number' || typeof transactionId !== 'number' || !transaction) {
    return res.status(400).json({ error: 'accountId, transactionId, and transaction are required' });
  }

  const { amount, description, date, merchant, isCredit } = transaction;
  const numericAmount = Number(amount);
  if (!Number.isFinite(numericAmount)) {
    return res.status(400).json({ error: 'Transaction amount must be a number' });
  }
  if (typeof description !== 'string' || description.trim() === '') {
    return res.status(400).json({ error: 'Transaction description is required' });
  }
  if (typeof isCredit !== 'boolean') {
    return res.status(400).json({ error: 'Transaction isCredit flag is required' });
  }

  const entryDate = typeof date === 'string' && date.trim() !== '' ? date : undefined;
  const merchantValue =
    typeof merchant === 'string'
      ? merchant.trim() || null
      : merchant === null
      ? null
      : undefined;

  try {
    const data = await readData();
    const accountIndex = data.accounts.findIndex((acc) => acc.id === accountId);

    if (accountIndex === -1) {
      return res.status(404).json({ error: 'Account not found' });
    }

    const account = data.accounts[accountIndex];
    const entries = account.transactions || [];
    const entryIndex = entries.findIndex((entry) => entry.id === transactionId);

    if (entryIndex === -1) {
      return res.status(404).json({ error: 'Transaction not found' });
    }

    const existing = entries[entryIndex];
    const oldSigned = existing.isCredit ? existing.amount : -existing.amount;
    const updated = {
      id: existing.id,
      amount: numericAmount,
      description: description.trim(),
      date: entryDate ?? existing.date,
      merchant: merchantValue !== undefined ? merchantValue : existing.merchant ?? null,
      isCredit
    };

    entries[entryIndex] = updated;
    account.transactions = entries;
    const newSigned = updated.isCredit ? updated.amount : -updated.amount;
    account.balance = Number(account.balance || 0) + (newSigned - oldSigned);
    data.accounts[accountIndex] = account;

    await writeData(data);
    res.status(200).json(updated);
  } catch (error) {
    console.error('Error updating transaction:', error);
    res.status(500).json({ error: 'Failed to update transaction' });
  }
});

app.delete('/delete-transaction', async (req, res) => {
  const { accountId, transactionId } = req.body;

  if (typeof accountId !== 'number' || typeof transactionId !== 'number') {
    return res.status(400).json({ error: 'accountId and transactionId are required' });
  }

  try {
    const data = await readData();
    const accountIndex = data.accounts.findIndex((acc) => acc.id === accountId);

    if (accountIndex === -1) {
      return res.status(404).json({ error: 'Account not found' });
    }

    const account = data.accounts[accountIndex];
    const entries = account.transactions || [];
    const entryIndex = entries.findIndex((entry) => entry.id === transactionId);

    if (entryIndex === -1) {
      return res.status(404).json({ error: 'Transaction not found' });
    }

    const [removed] = entries.splice(entryIndex, 1);
    account.transactions = entries;
    const signedAmount = removed.isCredit ? removed.amount : -removed.amount;
    account.balance = Number(account.balance || 0) - signedAmount;
    data.accounts[accountIndex] = account;

    await writeData(data);
    res.status(200).json({ message: 'Transaction deleted successfully' });
  } catch (error) {
    console.error('Error deleting transaction:', error);
    res.status(500).json({ error: 'Failed to delete transaction' });
  }
});

// Update the reset-balances endpoint to properly check excludeFromReset
app.post('/reset-balances', async (req, res) => {
  try {
    const data = await readData();
    
    // Reset all accounts and their pots
    data.accounts = data.accounts.map(account => {
      // Check if account is excluded from reset
      const isAccountExcluded = Boolean(account.excludeFromReset);
      
      return {
        ...account,
        // Only reset balance if not excluded
        balance: isAccountExcluded ? account.balance : 0,
        pots: (account.pots || []).map(pot => {
          const isPotExcluded = Boolean(pot.excludeFromReset);
          return {
            ...pot,
            // Only reset balance if neither pot nor account is excluded
            balance: isPotExcluded || isAccountExcluded ? pot.balance : 0,
            scheduled_payments: (pot.scheduled_payments || []).map(payment => ({
              ...payment,
              isCompleted: false,
              lastExecuted: null
            }))
          };
        }),
        scheduled_payments: (account.scheduled_payments || []).map(payment => ({
          ...payment,
          isCompleted: false,
          lastExecuted: null
        }))
      };
    });

    // Reset all income schedules
    if (data.income_schedules) {
      data.income_schedules = data.income_schedules.map(schedule => ({
        ...schedule,
        isCompleted: false,
        lastExecuted: null
      }));
    }

    await writeData(data);

    res.status(200).json({
      message: 'Balances and schedules reset successfully',
      accounts: data.accounts,
      income_schedules: data.income_schedules
    });
  } catch (error) {
    console.error('Error resetting balances:', error);
    res.status(500).json({ error: 'Failed to reset balances' });
  }
});

// Add new endpoint for executing all income schedules
app.post('/execute-all-income-schedules', (req, res) => {
  const filePath = path.join(__dirname, 'budget_data.json');

  fs.readFile(filePath, 'utf8', (err, data) => {
    if (err) {
      return res.status(500).send('Error reading file');
    }

    try {
      const budgetData = JSON.parse(data);
      const pendingSchedules = budgetData.income_schedules.filter(s => !s.isCompleted);
      
      // Execute all pending schedules
      pendingSchedules.forEach(schedule => {
        const account = budgetData.accounts.find(a => a.id === schedule.accountId);
        if (account) {
          account.balance += schedule.amount;
          schedule.isCompleted = true;
          schedule.lastExecuted = new Date().toISOString();
        }
      });

      fs.writeFile(filePath, JSON.stringify(budgetData, null, 2), 'utf8', (err) => {
        if (err) {
          return res.status(500).send('Error writing file');
        }
        res.status(200).json({
          message: 'All income schedules executed successfully',
          accounts: budgetData.accounts,
          executed_count: pendingSchedules.length
        });
      });
    } catch (error) {
      res.status(500).send('Error processing data');
    }
  });
});

app.delete('/delete-expense', (req, res) => {
  const { accountId, expenseId } = req.body;
  const filePath = path.join(__dirname, 'budget_data.json');

  fs.readFile(filePath, 'utf8', (err, data) => {
    if (err) {
      console.error('Error reading file:', err);
      return res.status(500).send('Error reading file');
    }

    try {
      const budgetData = JSON.parse(data);
      const account = budgetData.accounts.find(acc => acc.id === accountId);
      
      if (!account) {
        return res.status(404).send('Account not found');
      }

      const expenseIndex = account.expenses.findIndex(exp => exp.id === expenseId);
      if (expenseIndex === -1) {
        return res.status(404).send('Expense not found');
      }

      // Add back the expense amount to the balance before removing it
      const expense = account.expenses[expenseIndex];
      account.balance = parseFloat(account.balance) + parseFloat(expense.amount);
      
      // Remove the expense
      account.expenses.splice(expenseIndex, 1);
      
      fs.writeFile(filePath, JSON.stringify(budgetData, null, 2), 'utf8', (err) => {
        if (err) {
          return res.status(500).send('Error writing file');
        }
        res.status(200).json({ message: 'Expense deleted successfully' });
      });
    } catch (error) {
      res.status(500).send('Error processing data');
    }
  });
});

app.delete('/delete-income', (req, res) => {
  const { accountId, incomeId } = req.body;
  const filePath = path.join(__dirname, 'budget_data.json');

  fs.readFile(filePath, 'utf8', (err, data) => {
    if (err) {
      console.error('Error reading file:', err);
      return res.status(500).send('Error reading file');
    }

    try {
      const budgetData = JSON.parse(data);
      const account = budgetData.accounts.find(acc => acc.id === accountId);
      
      if (!account) {
        return res.status(404).send('Account not found');
      }

      const incomeIndex = account.incomes.findIndex(inc => inc.id === incomeId);
      if (incomeIndex === -1) {
        return res.status(404).send('Income not found');
      }

      // Subtract the income amount from the balance before removing it
      const income = account.incomes[incomeIndex];
      account.balance = parseFloat(account.balance) - parseFloat(income.amount);
      
      // Remove the income
      account.incomes.splice(incomeIndex, 1);
      
      fs.writeFile(filePath, JSON.stringify(budgetData, null, 2), 'utf8', (err) => {
        if (err) {
          return res.status(500).send('Error writing file');
        }
        res.status(200).json({ message: 'Income deleted successfully' });
      });
    } catch (error) {
      res.status(500).send('Error processing data');
    }
  });
});

app.get('/income-schedules', (req, res) => {
  const filePath = path.join(__dirname, 'budget_data.json');
  
  fs.readFile(filePath, 'utf8', (err, data) => {
    if (err) {
      return res.status(500).send('Error reading file');
    }
    
    try {
      const budgetData = JSON.parse(data);
      res.status(200).json(budgetData.income_schedules || []);
    } catch (error) {
      res.status(500).send('Error processing data');
    }
  });
});

app.post('/add-income-schedule', (req, res) => {
  const { accountId, incomeId, amount, description, company } = req.body;
  const filePath = path.join(__dirname, 'budget_data.json');

  fs.readFile(filePath, 'utf8', (err, data) => {
    if (err) {
      return res.status(500).send('Error reading file');
    }

    try {
      const budgetData = JSON.parse(data);
      
      if (!budgetData.income_schedules) {
        budgetData.income_schedules = [];
      }

      const newSchedule = {
        id: Date.now(),
        accountId,
        incomeId,
        amount,
        description,
        company,
        isActive: true,
        isCompleted: false
      };

      budgetData.income_schedules.push(newSchedule);

      fs.writeFile(filePath, JSON.stringify(budgetData, null, 2), 'utf8', (err) => {
        if (err) {
          return res.status(500).send('Error writing file');
        }
        res.status(200).json(newSchedule);
      });
    } catch (error) {
      res.status(500).send('Error processing data');
    }
  });
});

app.post('/execute-income-schedule', (req, res) => {
  const { scheduleId } = req.body;
  const filePath = path.join(__dirname, 'budget_data.json');

  fs.readFile(filePath, 'utf8', (err, data) => {
    if (err) {
      return res.status(500).send('Error reading file');
    }

    try {
      const budgetData = JSON.parse(data);
      const schedule = budgetData.income_schedules.find(s => s.id === scheduleId);
      
      if (!schedule || schedule.isCompleted) {
        return res.status(400).send('Invalid schedule or already completed');
      }

      const account = budgetData.accounts.find(a => a.id === schedule.accountId);
      if (!account) {
        return res.status(404).send('Account not found');
      }

      // Update account balance
      account.balance += schedule.amount;

      // Mark schedule as completed
      schedule.isCompleted = true;
      schedule.lastExecuted = new Date().toISOString();

      fs.writeFile(filePath, JSON.stringify(budgetData, null, 2), 'utf8', (err) => {
        if (err) {
          return res.status(500).send('Error writing file');
        }
        res.status(200).json({ message: 'Income schedule executed successfully' });
      });
    } catch (error) {
      res.status(500).send('Error processing data');
    }
  });
});

// Add new endpoint for deleting income schedules
app.delete('/delete-income-schedule', (req, res) => {
  const { scheduleId } = req.body;
  const filePath = path.join(__dirname, 'budget_data.json');

  fs.readFile(filePath, 'utf8', (err, data) => {
    if (err) return res.status(500).send('Error reading file');

    try {
      const budgetData = JSON.parse(data);
      const scheduleIndex = budgetData.income_schedules.findIndex(s => s.id === scheduleId);
      
      if (scheduleIndex === -1) return res.status(404).send('Schedule not found');

      // Remove the schedule
      budgetData.income_schedules.splice(scheduleIndex, 1);
      
      fs.writeFile(filePath, JSON.stringify(budgetData, null, 2), 'utf8', (err) => {
        if (err) return res.status(500).send('Error writing file');
        res.status(200).json({ message: 'Income schedule deleted successfully' });
      });
    } catch (error) {
      res.status(500).send('Error processing data');
    }
  });
});

// Add these new endpoints after existing account endpoints
app.get('/savings-investments', async (req, res) => {
  try {
    const data = await readData();
    const accounts = data.accounts.filter(acc => 
      acc.type === 'savings' || acc.type === 'investment'
    );
    res.status(200).json(accounts);
  } catch (error) {
    console.error('Error fetching savings/investments:', error);
    res.status(500).json({ error: 'Failed to fetch accounts' });
  }
});

app.post('/add-savings-investment', async (req, res) => {
  try {
    const data = await readData();
    const newAccount = {
      ...req.body,
      id: Date.now(),
      pots: [],
      scheduled_payments: [],
      excludeFromReset: true
    };
    
    data.accounts.push(newAccount);
    await writeData(data);
    
    res.status(200).json(newAccount);
  } catch (error) {
    console.error('Error adding savings/investment:', error);
    res.status(500).json({ error: 'Failed to add account' });
  }
});

app.listen(PORT, () => {
  console.log(`Server is running on http://localhost:${PORT}`);
});
