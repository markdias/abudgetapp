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
const executeTransfer = async (fromAccount, toAccount, amount, toPotName) => {
  if (fromAccount.balance < amount) {
    throw new Error('Insufficient balance');
  }

  fromAccount.balance -= amount;

  if (toPotName) {
    const pot = toAccount.pots.find(p => p.name === toPotName);
    if (!pot) {
      throw new Error('Destination pot not found');
    }
    pot.balance += amount;
  } else {
    toAccount.balance += amount;
  }
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
            transfer_schedules: []
          });
          return;
        }

        const budgetData = JSON.parse(data.trim());
        
        // Validate the structure
        if (!budgetData || typeof budgetData !== 'object') {
          throw new Error('Invalid JSON structure');
        }

        // Ensure required properties exist
        budgetData.accounts = budgetData.accounts || [];
        budgetData.scheduled_incomes = budgetData.scheduled_incomes || [];
        budgetData.income_schedules = budgetData.income_schedules || [];
        budgetData.transfer_schedules = budgetData.transfer_schedules || [];

        resolve(budgetData);
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
  const validatedData = {
    accounts: data.accounts || [],
    scheduled_incomes: data.scheduled_incomes || [],
    income_schedules: data.income_schedules || [],
    transfer_schedules: data.transfer_schedules || []
  };

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

    // Reset all transfer schedules
    if (data.transfer_schedules) {
      data.transfer_schedules = data.transfer_schedules.map(schedule => ({
        ...schedule,
        isCompleted: false,
        lastExecuted: null
      }));
    }

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
      income_schedules: data.income_schedules,
      transfer_schedules: data.transfer_schedules
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

// Get all transfer schedules
app.get('/transfer-schedules', (req, res) => {
  const filePath = path.join(__dirname, 'budget_data.json');
  
  fs.readFile(filePath, 'utf8', (err, data) => {
    if (err) {
      return res.status(500).send('Error reading file');
    }
    
    try {
      const budgetData = JSON.parse(data);
      res.status(200).json(budgetData.transfer_schedules || []);
    } catch (error) {
      res.status(500).send('Error processing data');
    }
  });
});

// Update add-transfer-schedule endpoint to remove isScheduled marking
app.post('/add-transfer-schedule', async (req, res) => {
  try {
    const { 
      fromAccountId, 
      fromPotId, 
      toAccountId, 
      toPotName,
      amount, 
      description,
      isDirectPotTransfer,
      items 
    } = req.body;

    const data = await readData();
    
    // Validate required fields
    if (!fromAccountId && !fromPotId) {
      throw new Error('Either fromAccountId or fromPotId is required');
    }
    if (!toAccountId) {
      throw new Error('toAccountId is required');
    }
    if (!amount || amount <= 0) {
      throw new Error('Valid amount is required');
    }

    const newSchedule = {
      id: Date.now(),
      fromAccountId,
      fromPotId,
      toAccountId,
      toPotName: isDirectPotTransfer ? toPotName : undefined,
      amount,
      description,
      isActive: true,
      isCompleted: false,
      items: items || [],
      isDirectPotTransfer,
      lastExecuted: null
    };

    if (!data.transfer_schedules) {
      data.transfer_schedules = [];
    }

    data.transfer_schedules.push(newSchedule);
    await writeData(data);
    
    res.json(newSchedule);
  } catch (error) {
    console.error('Error adding transfer schedule:', error);
    res.status(400).json({ error: error.message || 'Failed to add transfer schedule' });
  }
});

// Update the execute-transfer-schedule endpoint
const handleCreditCardPayment = async (accountId, amount, toPotName = null, toAccountId = null) => {
  const data = await readData();
  const creditCard = data.accounts.find(acc => acc.id === accountId);
  
  if (!creditCard || creditCard.type !== 'credit') {
    throw new Error('Invalid credit card account');
  }

  // Subtract amount from credit card balance
  creditCard.balance = Number((creditCard.balance - amount).toFixed(2));

  // If there's a destination pot, add the amount to it
  if (toPotName && toAccountId) {
    const destAccount = data.accounts.find(acc => acc.id === toAccountId);
    if (!destAccount) {
      throw new Error('Destination account not found');
    }

    const destPot = destAccount.pots?.find(p => p.name === toPotName);
    if (!destPot) {
      throw new Error('Destination pot not found');
    }

    destPot.balance = Number((destPot.balance + amount).toFixed(2));
  }

  await writeData(data);
  return { creditCard, updatedAccount: toAccountId ? data.accounts.find(acc => acc.id === toAccountId) : null };
};

app.post('/execute-transfer-schedule', async (req, res) => {
  const { scheduleId } = req.body;
  
  if (!scheduleId) {
    return res.status(400).json({ error: 'Schedule ID is required' });
  }

  try {
    const data = await readData();
    const schedule = data.transfer_schedules?.find(s => s.id === scheduleId);
    
    if (!schedule) {
      return res.status(404).json({ error: 'Schedule not found' });
    }

    if (schedule.isCompleted) {
      return res.status(400).json({ error: 'Schedule already completed' });
    }

    let fromAccount;
    let fromPot;

    // Handle transfers from pots
    if (schedule.fromPotId) {
      fromAccount = data.accounts.find(account => 
        account.pots?.some(pot => pot.name === schedule.fromPotId)
      );
      
      if (!fromAccount) {
        return res.status(404).json({ error: 'Source account not found' });
      }

      fromPot = fromAccount.pots.find(pot => pot.name === schedule.fromPotId);
      if (!fromPot) {
        return res.status(404).json({ error: 'Source pot not found' });
      }

      // Check pot balance before proceeding
      if (fromPot.balance < schedule.amount) {
        return res.status(400).json({ 
          error: 'Insufficient balance',
          details: `Pot "${fromPot.name}" has insufficient balance (${fromPot.balance} < ${schedule.amount})`
        });
      }
    } else {
      // Regular account-to-account transfer
      fromAccount = data.accounts.find(a => a.id === schedule.fromAccountId);
      if (!fromAccount) {
        return res.status(404).json({ error: 'Source account not found' });
      }

      // Check account balance before proceeding
      if (fromAccount.balance < schedule.amount) {
        return res.status(400).json({ 
          error: 'Insufficient balance',
          details: `Account "${fromAccount.name}" has insufficient balance (${fromAccount.balance} < ${schedule.amount})`
        });
      }
    }

    const toAccount = data.accounts.find(a => a.id === schedule.toAccountId);
    if (!toAccount) {
      return res.status(404).json({ error: 'Destination account not found' });
    }

    // Perform the transfer with proper error handling
    try {
      if (fromPot) {
        fromPot.balance = Number((fromPot.balance - schedule.amount).toFixed(2));
      } else {
        fromAccount.balance = Number((fromAccount.balance - schedule.amount).toFixed(2));
      }

      if (schedule.toPotName) {
        const toPot = toAccount.pots?.find(p => p.name === schedule.toPotName);
        if (!toPot) {
          throw new Error('Destination pot not found');
        }
        toPot.balance = Number((toPot.balance + schedule.amount).toFixed(2));
      } else {
        toAccount.balance = Number((toAccount.balance + schedule.amount).toFixed(2));
      }

      // Mark schedule as completed
      schedule.isCompleted = true;
      schedule.lastExecuted = new Date().toISOString();

      await writeData(data);

      res.status(200).json({
        success: true,
        schedule,
        accounts: [fromAccount, toAccount].filter(Boolean)
      });
    } catch (transferError) {
      // Revert changes if something goes wrong during transfer
      if (fromPot) {
        fromPot.balance = Number((fromPot.balance + schedule.amount).toFixed(2));
      } else {
        fromAccount.balance = Number((fromAccount.balance + schedule.amount).toFixed(2));
      }
      throw transferError;
    }
  } catch (error) {
    console.error('Error executing transfer schedule:', error);
    res.status(500).json({ 
      error: 'Failed to execute transfer schedule',
      details: error.message
    });
  }
});

app.delete('/delete-transfer-schedule', async (req, res) => {
  const { scheduleId } = req.body;
  if (!scheduleId) {
    return res.status(400).json({ error: 'Schedule ID is required' });
  }

  try {
    const data = await readData();
    // Convert scheduleId to number for comparison
    const numericScheduleId = Number(scheduleId);
    
    if (!data.transfer_schedules) {
      return res.status(404).json({ error: 'No transfer schedules found' });
    }

    const scheduleIndex = data.transfer_schedules.findIndex(s => Number(s.id) === numericScheduleId);
    
    if (scheduleIndex === -1) {
      return res.status(404).json({ error: 'Schedule not found' });
    }

    // Remove the schedule
    data.transfer_schedules.splice(scheduleIndex, 1);
    
    await writeData(data);
    
    res.status(200).json({ 
      message: 'Transfer schedule deleted successfully',
      deletedId: scheduleId 
    });
  } catch (error) {
    console.error('Error deleting transfer schedule:', error);
    res.status(500).json({ error: error.message || 'Failed to delete transfer schedule' });
  }
});

// Add this endpoint to execute all pending transfer schedules
app.post('/execute-all-transfer-schedules', async (req, res) => {
  try {
    const data = await readData();
    const pendingSchedules = data.transfer_schedules?.filter(s => !s.isCompleted) || [];
    let executedCount = 0;

    // Execute all pending schedules
    for (const schedule of pendingSchedules) {
      const fromAccount = data.accounts.find(a => a.id === schedule.fromAccountId);
      const toAccount = data.accounts.find(a => a.id === schedule.toAccountId);

      if (fromAccount && toAccount && fromAccount.balance >= schedule.amount) {
        try {
          // Perform the transfer
          fromAccount.balance = Number((fromAccount.balance - schedule.amount).toFixed(2));
          
          if (schedule.toPotName) {
            const toPot = toAccount.pots?.find(p => p.name === schedule.toPotName);
            if (toPot) {
              toPot.balance = Number((toPot.balance + schedule.amount).toFixed(2));
            }
          } else {
            toAccount.balance = Number((toAccount.balance + schedule.amount).toFixed(2));
          }

          // Mark schedule as completed
          schedule.isCompleted = true;
          schedule.lastExecuted = new Date().toISOString();
          executedCount++;
        } catch (error) {
          console.error('Error executing schedule:', error);
          // Revert changes if something goes wrong
          fromAccount.balance = Number((fromAccount.balance + schedule.amount).toFixed(2));
        }
      }
    }

    await writeData(data);

    res.status(200).json({
      message: 'Transfer schedules executed successfully',
      accounts: data.accounts,
      executed_count: executedCount
    });
  } catch (error) {
    console.error('Error executing transfer schedules:', error);
    res.status(500).json({
      error: 'Failed to execute transfer schedules',
      details: error.message
    });
  }
});

// Add scheduled payment endpoint
app.post('/add-scheduled-payment', async (req, res) => {
  const { accountId, payment } = req.body;

  // Validate request body
  if (!accountId || !payment) {
    return res.status(400).json({ error: 'Invalid request data' });
  }

  // Validate required payment fields
  const requiredFields = ['name', 'amount', 'date', 'company', 'type']; // Add type to required fields
  const missingFields = requiredFields.filter(field => {
    const value = payment[field];
    return value === undefined || value === null || value === '' || 
           (typeof value === 'string' && value.trim() === '') ||
           (field === 'amount' && (isNaN(value) || value <= 0));
  });

  if (missingFields.length > 0) {
    return res.status(400).json({
      error: 'Missing or invalid required fields',
      missingFields
    });
  }

  try {
    const data = await readData();
    const account = data.accounts.find(acc => acc.id === accountId);
    
    if (!account) {
      return res.status(404).json({ error: 'Account not found' });
    }

    const newPayment = {
      ...payment,
      id: Date.now(),
      name: payment.name.trim(),
      amount: Number(payment.amount),
      company: payment.company.trim(),
      type: payment.type, // Add this line
      isCompleted: false,
      lastExecuted: null
    };

    if (payment.potName) {
      // Handle pot payment
      const pot = account.type === 'credit'
        ? data.accounts
            .filter(acc => acc.type !== 'credit')
            .flatMap(acc => acc.pots || [])
            .find(p => p.name === payment.potName)
        : account.pots?.find(p => p.name === payment.potName);

      if (!pot) {
        return res.status(404).json({ error: 'Pot not found' });
      }

      pot.scheduled_payments = pot.scheduled_payments || [];
      pot.scheduled_payments.push(newPayment);
    } else {
      // Handle regular account payment
      account.scheduled_payments = account.scheduled_payments || [];
      account.scheduled_payments.push(newPayment);
    }

    await writeData(data);
    res.status(200).json(newPayment);
  } catch (error) {
    console.error('Error adding scheduled payment:', error);
    res.status(500).json({ 
      error: 'Error processing payment',
      details: error.message 
    });
  }
});

app.put('/update-account', async (req, res) => {
  const { accountId, updatedAccount } = req.body;
  
  try {
    const data = await readData();
    const account = data.accounts.find(acc => acc.id === accountId);
    
    if (!account) {
      return res.status(404).json({ error: 'Account not found' });
    }

    // Ensure balance is a valid number
    const balance = Number(updatedAccount.balance);
    if (isNaN(balance)) {
      return res.status(400).json({ error: 'Invalid balance amount' });
    }
    
    const updatedAccountData = {
      ...account,
      name: updatedAccount.name,
      balance: balance, // Store as number
      type: updatedAccount.type,
      accountType: updatedAccount.accountType || account.accountType,
      excludeFromReset: Boolean(updatedAccount.excludeFromReset)
    };

    data.accounts = data.accounts.map(acc => 
      acc.id === accountId ? updatedAccountData : acc
    );
    
    await writeData(data);
    
    res.status(200).json(updatedAccountData);
  } catch (error) {
    console.error('Error updating account:', error);
    res.status(500).json({ error: error.message || 'Failed to update account' });
  }
});

app.post('/toggle-account-exclusion', async (req, res) => {
  const { accountId } = req.body;
  
  try {
    const data = await readData();
    const account = data.accounts.find(acc => acc.id === accountId);
    
    if (!account) {
      return res.status(404).send('Account not found');
    }

    account.excludeFromReset = !account.excludeFromReset;
    await writeData(data);
    
    res.status(200).json({ excludeFromReset: account.excludeFromReset });
  } catch (error) {
    console.error('Error toggling account exclusion:', error);
    res.status(500).send('Error updating account');
  }
});

app.post('/toggle-pot-exclusion', async (req, res) => {
  const { accountId, potName } = req.body;
  
  try {
    const data = await readData();
    const account = data.accounts.find(acc => acc.id === accountId);
    
    if (!account) {
      return res.status(404).send('Account not found');
    }

    const pot = account.pots?.find(p => p.name === potName);
    if (!pot) {
      return res.status(404).send('Pot not found');
    }

    pot.excludeFromReset = !pot.excludeFromReset;
    await writeData(data);
    
    res.status(200).json({ excludeFromReset: pot.excludeFromReset });
  } catch (error) {
    console.error('Error toggling pot exclusion:', error);
    res.status(500).send('Error updating pot');
  }
});

// Add this new endpoint
app.delete('/delete-account', async (req, res) => {
  const { accountId } = req.body;
  
  try {
    const data = await readData();
    const accountIndex = data.accounts.findIndex(acc => acc.id === accountId);
    
    if (accountIndex === -1) {
      return res.status(404).json({ error: 'Account not found' });
    }

    // Remove account
    data.accounts.splice(accountIndex, 1);

    // Also clean up any related schedules
    if (data.transfer_schedules) {
      data.transfer_schedules = data.transfer_schedules.filter(schedule => 
        schedule.fromAccountId !== accountId && schedule.toAccountId !== accountId
      );
    }

    if (data.income_schedules) {
      data.income_schedules = data.income_schedules.filter(schedule => 
        schedule.accountId !== accountId
      );
    }

    await writeData(data);
    res.status(200).json({ message: 'Account deleted successfully' });
  } catch (error) {
    console.error('Error deleting account:', error);
    res.status(500).json({ error: 'Failed to delete account' });
  }
});

// Update the /get-available-transfers endpoint to ensure consistent structure
app.get('/get-available-transfers', async (req, res) => {
  try {
    const data = await readData();
    const groupedTransfers = {
      byAccount: [],
      byPot: []
    };

    data.accounts.forEach(account => {
      // Group account expenses
      if (account.expenses?.length > 0) {
        groupedTransfers.byAccount.push({
          destinationId: account.id,
          destinationType: 'account',
          destinationName: `${account.name} Expenses`,
          accountName: account.name,
          totalAmount: account.expenses.reduce((sum, exp) => sum + exp.amount, 0),
          items: account.expenses.map(expense => ({
            id: expense.id,
            amount: expense.amount,
            description: expense.description,
            date: expense.date,
            type: 'expense'
          }))
        });
      }

      // Group pot payments with scheduled payments
      account.pots?.forEach(pot => {
        if (pot.scheduled_payments?.length > 0) {
          // Ensure all payments have a type
          const payments = pot.scheduled_payments.map(payment => ({
            ...payment,
            type: payment.type || 'direct_debit' // Default to direct_debit if no type
          }));

          // Separate direct debits and card payments
          const directDebits = payments.filter(p => p.type === 'direct_debit');
          const cardPayments = payments.filter(p => p.type === 'card');

          if (payments.length > 0) {
            groupedTransfers.byPot.push({
              destinationId: account.id,
              destinationType: 'pot',
              destinationName: pot.name,
              accountName: account.name,
              totalAmount: payments.reduce((sum, payment) => sum + payment.amount, 0),
              items: {
                directDebits: directDebits.map(payment => ({
                  id: payment.id,
                  amount: payment.amount,
                  description: payment.name,
                  date: payment.date,
                  company: payment.company,
                  type: 'direct_debit'
                })),
                cardPayments: cardPayments.map(payment => ({
                  id: payment.id,
                  amount: payment.amount,
                  description: payment.name,
                  date: payment.date,
                  company: payment.company,
                  type: 'card'
                }))
              }
            });
          }
        }
      });
    });

    res.json(groupedTransfers);
  } catch (error) {
    console.error('Error getting available transfers:', error);
    res.status(500).json({ error: 'Failed to get available transfers' });
  }
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
